import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AsaasWebhookProcessingStatus,
  EngagementStatus,
  PaymentStatus,
  Prisma,
  SplitRecipientType,
  SplitStatus,
} from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { asaasPaymentStatus, asaasSplitStatus } from './asaas-payment-state';
import { AsaasChargeResponse, AsaasService } from './asaas.service';

type ReconciliationContext = {
  eventType?: string;
  splitId?: string;
  webhookEventId?: string;
  authoritative?: boolean;
  pixCopyPaste?: string;
  pixExpirationDate?: string;
};

export function asaasPaymentMetadata(value: Prisma.JsonValue | null) {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Prisma.InputJsonObject)
    : {};
}

@Injectable()
export class AsaasPaymentReconciliationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly asaasService: AsaasService,
  ) {}

  async refresh(paymentId: string) {
    const payment = await this.prisma.payment.findUnique({
      where: { id: paymentId },
      include: { splits: true },
    });
    if (!payment) throw new NotFoundException('Pagamento nao encontrado.');
    if (payment.provider !== 'asaas') return payment;
    this.assertEnvironment(payment.providerPayload);

    const charge = payment.providerPaymentId
      ? await this.asaasService.getCharge(payment.providerPaymentId)
      : await this.asaasService.findChargeByExternalReference(payment.id);
    if (!charge) return this.recoverAbandonedCreation(payment.id);

    let pix: { payload?: string; expirationDate?: string } | undefined;
    if (
      !asaasPaymentMetadata(payment.providerPayload).pixCopyPaste &&
      charge.status === 'PENDING'
    ) {
      pix = await this.asaasService
        .getPixQrCode(charge.id)
        .catch(() => undefined);
    }
    return this.applyCharge(payment.id, charge, {
      authoritative: true,
      pixCopyPaste: pix?.payload,
      pixExpirationDate: pix?.expirationDate,
    });
  }

  private assertEnvironment(payload: Prisma.JsonValue | null) {
    const raw = asaasPaymentMetadata(payload).environment;
    const environment = typeof raw === 'string' ? raw.toLowerCase() : undefined;
    const configured = this.asaasService.getEnvironment();
    if (environment ? environment !== configured : configured !== 'sandbox') {
      throw new ConflictException(
        'O ambiente desta cobranca precisa ser conciliado antes da atualizacao.',
      );
    }
  }

  private async recoverAbandonedCreation(paymentId: string) {
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM public.payments WHERE id = ${paymentId}::uuid FOR UPDATE`;
      const payment = await tx.payment.findUniqueOrThrow({
        where: { id: paymentId },
        include: { splits: true },
      });
      this.assertEnvironment(payment.providerPayload);
      const metadata = asaasPaymentMetadata(payment.providerPayload);
      const recordedStart =
        typeof metadata.creationStartedAt === 'string'
          ? Date.parse(metadata.creationStartedAt)
          : NaN;
      const startedAt = Number.isFinite(recordedStart)
        ? recordedStart
        : payment.createdAt.getTime();
      const abandoned =
        !payment.providerPaymentId &&
        payment.status === PaymentStatus.PENDING &&
        payment.providerStatus === 'CREATING' &&
        Date.now() - startedAt > 5 * 60_000;
      const failedCreation =
        !payment.providerPaymentId &&
        payment.status === PaymentStatus.FAILED &&
        payment.providerStatus === 'CREATE_FAILED';
      if (abandoned || failedCreation) {
        if (abandoned)
          await tx.payment.update({
            where: { id: payment.id },
            data: {
              status: PaymentStatus.FAILED,
              providerStatus: 'CREATE_FAILED',
            },
          });
        // This path is reached only after a successful negative lookup at Asaas.
        const changed = await tx.paymentSplit.updateMany({
          where: {
            paymentId: payment.id,
            status: { in: [SplitStatus.PENDING, SplitStatus.SCHEDULED] },
          },
          data: { status: SplitStatus.FAILED },
        });
        if (changed.count)
          await tx.auditLog.create({
            data: {
              actorType: 'SYSTEM',
              action: 'ASAAS_CREATE_FAILURE_RECONCILED',
              entityType: 'PAYMENT',
              entityId: payment.id,
            },
          });
        return tx.payment.findUniqueOrThrow({
          where: { id: payment.id },
          include: { splits: true },
        });
      }
      return payment;
    });
  }

  async applyCharge(
    paymentId: string,
    charge: AsaasChargeResponse,
    context: ReconciliationContext = {},
  ) {
    return this.prisma.$transaction(async (tx) => {
      // Serialize creation responses, refreshes and duplicated/out-of-order events.
      await tx.$queryRaw`SELECT id FROM public.payments WHERE id = ${paymentId}::uuid FOR UPDATE`;
      const payment = await tx.payment.findUnique({
        where: { id: paymentId },
        include: { splits: true },
      });
      if (!payment) throw new NotFoundException('Pagamento nao encontrado.');
      this.assertEnvironment(payment.providerPayload);
      const metadata = asaasPaymentMetadata(payment.providerPayload);
      const expectedAmount = new Prisma.Decimal(
        typeof metadata.chargeAmount === 'number'
          ? metadata.chargeAmount
          : payment.grossAmount,
      );
      if (
        payment.provider !== 'asaas' ||
        !charge.id ||
        typeof charge.status !== 'string' ||
        charge.externalReference !== payment.id ||
        (payment.providerPaymentId &&
          payment.providerPaymentId !== charge.id) ||
        typeof charge.value !== 'number' ||
        !Number.isFinite(charge.value) ||
        !expectedAmount.equals(charge.value)
      ) {
        throw new ConflictException(
          'Os dados da cobranca divergem do pagamento registrado.',
        );
      }

      const professionalSplit = (
        Array.isArray(charge.split) ? charge.split : []
      ).find(
        (item) => item.externalReference === `payment-split-${payment.id}`,
      );
      if (metadata.pricingModel === 'INSTITUTION_PAYS_GATEWAY_FEE') {
        if (
          charge.billingType !== 'PIX' ||
          charge.split?.length !== 1 ||
          !professionalSplit ||
          (professionalSplit.percentualValue ?? 0) !== 0 ||
          professionalSplit.walletId !== metadata.professionalWalletId ||
          !payment.netAmount.equals(professionalSplit.fixedValue ?? -1)
        ) {
          throw new ConflictException(
            'O split da cobranca diverge da carteira ou do contrato.',
          );
        }
      }

      if (context.webhookEventId) {
        const event = await tx.asaasWebhookEvent.findUnique({
          where: { id: context.webhookEventId },
        });
        if (
          event?.processingStatus === AsaasWebhookProcessingStatus.PROCESSED
        ) {
          return payment;
        }
      }

      const heldDispute =
        payment.providerStatus?.includes('CHARGEBACK') &&
        !charge.status.includes('CHARGEBACK') &&
        !context.authoritative;
      const status = heldDispute
        ? PaymentStatus.FAILED
        : asaasPaymentStatus(payment.status, charge.status);
      const regressive =
        status !== asaasPaymentStatus(PaymentStatus.PENDING, charge.status);
      const now = new Date();
      const hasNetValue =
        typeof charge.netValue === 'number' && Number.isFinite(charge.netValue);
      const isRefund =
        status === PaymentStatus.REFUNDED ||
        status === PaymentStatus.PARTIALLY_REFUNDED;
      const financialDivergence =
        metadata.pricingModel === 'INSTITUTION_PAYS_GATEWAY_FEE' &&
        !regressive &&
        !isRefund &&
        hasNetValue &&
        !payment.grossAmount.equals(charge.netValue!);
      if (financialDivergence && !payment.providerPaymentId) {
        throw new ConflictException(
          'A tarifa retornada pelo Asaas mudou. A cobranca precisa ser conciliada antes do pagamento.',
        );
      }
      const nextMetadata: Prisma.InputJsonObject = {
        ...metadata,
        lastSynchronizedAt: now.toISOString(),
        ...(context.pixCopyPaste ? { pixCopyPaste: context.pixCopyPaste } : {}),
        ...(context.pixExpirationDate
          ? { pixExpirationDate: context.pixExpirationDate }
          : {}),
        ...(!regressive && !isRefund && hasNetValue
          ? {
              gatewayNetValue: charge.netValue!,
              settledGatewayFeeAmount: new Prisma.Decimal(charge.value!)
                .minus(charge.netValue!)
                .toNumber(),
              financialDivergence,
            }
          : {}),
      };
      const splitProblem =
        context.eventType === 'PAYMENT_SPLIT_DIVERGENCE_BLOCK' ||
        context.eventType === 'PAYMENT_SPLIT_CANCELLED';
      await tx.payment.update({
        where: { id: payment.id },
        data: {
          providerPaymentId: charge.id,
          checkoutUrl:
            financialDivergence && !payment.checkoutUrl
              ? null
              : (charge.invoiceUrl ?? payment.checkoutUrl),
          providerStatus: splitProblem
            ? context.eventType
            : regressive
              ? payment.providerStatus
              : charge.status,
          status,
          providerPayload: nextMetadata,
          ...(status === PaymentStatus.PAID && !payment.paidAt
            ? { paidAt: now }
            : {}),
          ...((status === PaymentStatus.REFUNDED ||
            status === PaymentStatus.PARTIALLY_REFUNDED) &&
          !payment.refundedAt
            ? { refundedAt: now }
            : {}),
        },
      });

      for (const split of payment.splits) {
        const isProfessional =
          split.recipientType === SplitRecipientType.PROFESSIONAL;
        const doneEvent =
          isProfessional &&
          context.eventType === 'PAYMENT_SPLIT_DONE' &&
          !!context.splitId &&
          professionalSplit?.id === context.splitId;
        let next = isProfessional
          ? asaasSplitStatus({
              current: split.status,
              paymentStatus: status,
              providerStatus: professionalSplit?.status,
              eventType: heldDispute
                ? 'PAYMENT_CHARGEBACK_DISPUTE'
                : context.eventType,
              splitDone: doneEvent,
              authoritative: context.authoritative,
            })
          : asaasSplitStatus({
              current: split.status,
              paymentStatus: status,
              providerStatus: splitProblem
                ? 'CANCELLED'
                : status === PaymentStatus.PAID
                  ? 'DONE'
                  : undefined,
              eventType: heldDispute
                ? 'PAYMENT_CHARGEBACK_DISPUTE'
                : context.eventType,
              authoritative: context.authoritative,
            });
        if (financialDivergence || (splitProblem && !isProfessional)) {
          next = SplitStatus.FAILED;
        }
        await tx.paymentSplit.update({
          where: { id: split.id },
          data: {
            status: next,
            ...(isProfessional && professionalSplit?.id
              ? {
                  transferReference: professionalSplit.id,
                }
              : {}),
            ...(next === SplitStatus.TRANSFERRED && !split.processedAt
              ? {
                  processedAt: now,
                }
              : {}),
          },
        });
      }

      if (
        !financialDivergence &&
        (status === PaymentStatus.PAID || status === PaymentStatus.AUTHORIZED)
      ) {
        await tx.engagement.updateMany({
          where: {
            id: payment.engagementId,
            status: EngagementStatus.PENDING_PAYMENT,
          },
          data: { status: EngagementStatus.CONFIRMED, confirmedAt: now },
        });
      }
      if (financialDivergence || charge.status.includes('CHARGEBACK')) {
        await tx.engagement.updateMany({
          where: {
            id: payment.engagementId,
            status: { not: EngagementStatus.CANCELLED },
          },
          data: { status: EngagementStatus.DISPUTED },
        });
      }
      if (context.webhookEventId) {
        await tx.asaasWebhookEvent.update({
          where: { id: context.webhookEventId },
          data: {
            processingStatus: AsaasWebhookProcessingStatus.PROCESSED,
            processedAt: now,
          },
        });
      }
      return tx.payment.findUniqueOrThrow({
        where: { id: payment.id },
        include: { splits: true },
      });
    });
  }
}
