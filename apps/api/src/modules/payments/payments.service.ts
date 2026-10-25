import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AsaasAccountStatus,
  AsaasEnvironment,
  AsaasOnboardingStatus,
  EngagementStatus,
  PaymentStatus,
  Prisma,
  SplitRecipientType,
  SplitStatus,
} from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AsaasService } from '../asaas/asaas.service';
import {
  AsaasPaymentReconciliationService,
} from '../asaas/asaas-payment-reconciliation.service';
import { AuthenticatedUser } from '../auth/current-user.decorator';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { QuotePaymentDto } from './dto/quote-payment.dto';
import { PaymentProvider } from './payment-provider';

type CheckoutEngagement = Prisma.EngagementGetPayload<{
  include: {
    institution: {
      include: { user: { select: { email: true } }; address: true };
    };
    payment: { include: { splits: true } };
  };
}>;

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly paymentProvider: PaymentProvider,
    private readonly asaasService: AsaasService,
    private readonly reconciliation: AsaasPaymentReconciliationService,
  ) {}

  private async checkoutEngagement(engagementId: string, user: AuthenticatedUser) {
    const engagement = await this.prisma.engagement.findUnique({
      where: { id: engagementId },
      include: {
        institution: {
          include: {
            user: {
              select: {
                email: true,
              },
            },
            address: true,
          },
        },
        payment: {
          include: {
            splits: true,
          },
        },
      },
    });

    if (!engagement) {
      throw new NotFoundException('Fechamento nao encontrado.');
    }

    if (engagement.institution.userId !== user.userId) {
      throw new ForbiddenException('Voce nao pode criar pagamento para este fechamento.');
    }

    return engagement;
  }

  async quote(dto: QuotePaymentDto, user: AuthenticatedUser) {
    const engagement = await this.checkoutEngagement(dto.engagementId, user);
    if (engagement.status !== EngagementStatus.PENDING_PAYMENT) {
      throw new ConflictException('Este contrato nao esta aguardando pagamento.');
    }
    if (!this.asaasService.isEnabled()) {
      throw new ConflictException('O gateway Asaas precisa estar habilitado para simular o Pix.');
    }
    const amounts = await this.asaasService.quotePixCharge(Number(engagement.grossAmount));
    return {
      ...amounts,
      serviceAmount: Number(engagement.netAmount),
      subtotalAmount: Number(engagement.grossAmount),
      platformFeeAmount: Number(engagement.platformFeeAmount),
      professionalAmount: Number(engagement.netAmount),
      gatewayFeePayer: 'INSTITUTION',
      platformFeePayer: 'INSTITUTION',
      environment: this.asaasService.getEnvironment(),
      expiresAt: new Date(Date.now() + 5 * 60_000).toISOString(),
    };
  }

  async create(dto: CreatePaymentDto, user: AuthenticatedUser) {
    const engagement = await this.checkoutEngagement(dto.engagementId, user);
    if (engagement.payment && !(
      this.asaasService.isEnabled() && engagement.payment.provider === 'asaas' &&
      engagement.payment.status === PaymentStatus.FAILED && !engagement.payment.providerPaymentId
    )) {
      const payment = engagement.payment.provider === 'asaas' && this.asaasService.isEnabled()
        ? await this.reconciliation.refresh(engagement.payment.id)
        : engagement.payment;
      return { message: 'Pagamento existente recuperado.', payment };
    }
    if (engagement.status !== EngagementStatus.PENDING_PAYMENT) {
      throw new ConflictException('Este contrato nao esta aguardando pagamento.');
    }

    if (this.asaasService.isEnabled()) {
      if (dto.expectedChargeAmount === undefined) {
        throw new BadRequestException('Confirme o valor total com a tarifa antes de gerar o Pix.');
      }
      return this.createAsaasPayment(engagement, dto.expectedChargeAmount);
    }

    if (process.env.NODE_ENV === 'production') {
      throw new ConflictException('O gateway de pagamentos precisa estar configurado antes de gerar cobrancas.');
    }

    const paymentIntent = this.paymentProvider.createPaymentIntent({
      engagementId: dto.engagementId,
      grossAmount: engagement.grossAmount,
      platformFeeAmount: engagement.platformFeeAmount,
      netAmount: engagement.netAmount,
    });

    const payment = await this.prisma.$transaction(async (tx) => {
      const createdPayment = await tx.payment.create({
        data: {
          engagementId: dto.engagementId,
          provider: paymentIntent.provider,
          providerPaymentId: paymentIntent.providerPaymentId,
          providerStatus: paymentIntent.providerStatus,
          checkoutUrl: paymentIntent.checkoutUrl,
          providerPayload: paymentIntent.providerPayload,
          status: PaymentStatus.PENDING,
          grossAmount: engagement.grossAmount,
          platformFeeAmount: engagement.platformFeeAmount,
          netAmount: engagement.netAmount,
        },
      });

      await tx.paymentSplit.createMany({
        data: [
          {
            paymentId: createdPayment.id,
            recipientType: SplitRecipientType.PLATFORM,
            amount: engagement.platformFeeAmount,
            status: SplitStatus.PENDING,
          },
          {
            paymentId: createdPayment.id,
            recipientType: SplitRecipientType.PROFESSIONAL,
            recipientId: engagement.professionalUserId,
            amount: engagement.netAmount,
            status: SplitStatus.PENDING,
          },
        ],
      });

      return tx.payment.findUnique({
        where: { id: createdPayment.id },
        include: {
          splits: true,
        },
      });
    });

    return {
      message: 'Checkout sandbox criado com sucesso.',
      payment,
    };
  }

  private async createAsaasPayment(
    engagement: CheckoutEngagement,
    expectedChargeAmount: number,
  ) {
    const environment =
      this.asaasService.getEnvironment() === 'production'
        ? AsaasEnvironment.PRODUCTION
        : AsaasEnvironment.SANDBOX;
    const professionalAccount = await this.prisma.asaasAccount.findUnique({
      where: {
        userId_environment: {
          userId: engagement.professionalUserId,
          environment,
        },
      },
    });

    if (
      !professionalAccount?.asaasWalletId ||
      professionalAccount.onboardingStatus !==
        AsaasOnboardingStatus.APPROVED ||
      professionalAccount.accountStatus === AsaasAccountStatus.BLOCKED ||
      professionalAccount.accountStatus === AsaasAccountStatus.REJECTED
    ) {
      throw new ConflictException(
        'O profissional precisa ter uma conta Asaas aprovada antes da cobranca.',
      );
    }

    const quote = await this.asaasService.quotePixCharge(Number(engagement.grossAmount));
    if (!new Prisma.Decimal(expectedChargeAmount).equals(quote.chargeAmount)) {
      throw new ConflictException(
        'A tarifa do Pix mudou. Atualize a simulacao e confirme o novo total.',
      );
    }
    const metadata: Prisma.InputJsonObject = {
      ...quote,
      serviceAmount: Number(engagement.netAmount),
      subtotalAmount: Number(engagement.grossAmount),
      platformFeeAmount: Number(engagement.platformFeeAmount),
      professionalAmount: Number(engagement.netAmount),
      pricingModel: 'INSTITUTION_PAYS_GATEWAY_FEE',
      gatewayFeePayer: 'INSTITUTION',
      platformFeePayer: 'INSTITUTION',
      professionalWalletId: professionalAccount.asaasWalletId,
      environment: this.asaasService.getEnvironment(),
      creationStartedAt: new Date().toISOString(),
    };
    let payment: { id: string };
    if (engagement.payment) {
      const claimed = await this.prisma.payment.updateMany({
        where: {
          id: engagement.payment.id,
          status: PaymentStatus.FAILED,
          providerPaymentId: null,
        },
        data: {
          status: PaymentStatus.PENDING,
          providerStatus: 'CREATING',
          providerPayload: metadata,
        },
      });
      if (!claimed.count) {
        return {
          message: 'Pagamento existente recuperado.',
          payment: await this.prisma.payment.findUniqueOrThrow({
            where: { id: engagement.payment.id }, include: { splits: true },
          }),
        };
      }
      payment = engagement.payment;
    } else {
      try {
        payment = await this.prisma.$transaction(async (tx) => {
        const created = await tx.payment.create({
          data: {
            engagementId: engagement.id,
            provider: 'asaas',
            providerStatus: 'CREATING',
            status: PaymentStatus.PENDING,
            grossAmount: engagement.grossAmount,
            platformFeeAmount: engagement.platformFeeAmount,
            netAmount: engagement.netAmount,
            providerPayload: metadata,
          },
        });

        await tx.paymentSplit.createMany({
          data: [
            {
              paymentId: created.id,
              recipientType: SplitRecipientType.PLATFORM,
              amount: engagement.platformFeeAmount,
              status: SplitStatus.PENDING,
            },
            {
              paymentId: created.id,
              recipientType: SplitRecipientType.PROFESSIONAL,
              recipientId: engagement.professionalUserId,
              amount: engagement.netAmount,
              status: SplitStatus.PENDING,
            },
          ],
        });

        return created;
        });
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
          return {
            message: 'Pagamento existente recuperado.',
            payment: await this.prisma.payment.findUniqueOrThrow({
              where: { engagementId: engagement.id }, include: { splits: true },
            }),
          };
        }
        throw error;
      }
    }

    let createdChargeId: string | undefined;
    try {
      const customer = await this.asaasService.ensureCustomer({
        externalReference: `vetfinder-institution-${engagement.institution.id}`,
        name:
          engagement.institution.tradeName || engagement.institution.legalName,
        cpfCnpj: engagement.institution.cnpj,
        email: engagement.institution.user.email,
        mobilePhone: engagement.institution.contactPhone ?? undefined,
        address: engagement.institution.address?.street ?? undefined,
        addressNumber: engagement.institution.address?.number ?? undefined,
        complement: engagement.institution.address?.complement ?? undefined,
        province: engagement.institution.address?.district ?? undefined,
        postalCode: engagement.institution.address?.zipCode ?? undefined,
      });
      const charge = await this.asaasService.createPixCharge({
        customerId: customer.id,
        externalReference: payment.id,
        description: `Plantao VetFinder ${engagement.id}`,
        value: quote.chargeAmount,
        dueDate: this.tomorrowDate(),
        professionalWalletId: professionalAccount.asaasWalletId,
        professionalAmount: Number(engagement.netAmount),
        splitExternalReference: `payment-split-${payment.id}`,
      });
      createdChargeId = charge.id;

      let pixQrCode:
        | { payload?: string; expirationDate?: string }
        | undefined;
      try {
        pixQrCode = await this.asaasService.getPixQrCode(charge.id);
      } catch {
        // A fatura continua valida mesmo quando o QR Code nao esta disponivel.
      }

      const updated = await this.reconciliation.applyCharge(payment.id, charge, {
        pixCopyPaste: pixQrCode?.payload,
        pixExpirationDate: pixQrCode?.expirationDate,
      });

      return {
        message: 'Cobranca Pix Asaas criada com sucesso.',
        payment: updated,
      };
    } catch (error) {
      const recovered = await this.prisma.payment.findUniqueOrThrow({
        where: { id: payment.id }, include: { splits: true },
      });
      if (recovered.providerPaymentId && recovered.status !== PaymentStatus.FAILED) {
        return { message: 'Pagamento existente recuperado.', payment: recovered };
      }
      await this.prisma.payment.updateMany({
        where: {
          id: payment.id, providerPaymentId: null,
          status: PaymentStatus.PENDING, providerStatus: 'CREATING',
        },
        data: {
          status: PaymentStatus.FAILED,
          providerStatus: createdChargeId ? 'RECONCILIATION_REQUIRED' : 'CREATE_FAILED',
          ...(createdChargeId ? { providerPaymentId: createdChargeId } : {}),
        },
      });
      throw error;
    }
  }

  private tomorrowDate() {
    return new Date(Date.now() + 24 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10);
  }

  async confirmSandboxPayment(paymentId: string, user: AuthenticatedUser) {
    if (this.asaasService.isEnabled()) {
      throw new ForbiddenException(
        'A confirmacao manual fica desabilitada quando o Asaas esta ativo.',
      );
    }

    const payment = await this.prisma.payment.findUnique({
      where: { id: paymentId },
      include: {
        engagement: {
          include: {
            institution: true,
          },
        },
      },
    });

    if (!payment) {
      throw new NotFoundException('Pagamento nao encontrado.');
    }

    if (payment.engagement.institution.userId !== user.userId) {
      throw new ForbiddenException('Voce nao pode confirmar este pagamento.');
    }

    if (payment.provider !== 'sandbox-split' || process.env.NODE_ENV === 'production') {
      throw new ForbiddenException('A confirmacao manual so pode ser usada no simulador local.');
    }

    if (payment.status === PaymentStatus.PAID) {
      throw new ConflictException('Este pagamento ja esta confirmado.');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      await tx.payment.update({
        where: { id: paymentId },
        data: {
          status: PaymentStatus.PAID,
          providerStatus: 'PAID_SANDBOX',
          paidAt: new Date(),
        },
      });

      await tx.paymentSplit.updateMany({
        where: { paymentId },
        data: {
          status: SplitStatus.SCHEDULED,
        },
      });

      await tx.engagement.update({
        where: { id: payment.engagementId },
        data: {
          status: EngagementStatus.CONFIRMED,
          confirmedAt: new Date(),
        },
      });

      return tx.payment.findUnique({
        where: { id: paymentId },
        include: { splits: true },
      });
    });

    return {
      message: 'Pagamento sandbox confirmado com sucesso.',
      payment: updated,
    };
  }

  async findOne(id: string, user: AuthenticatedUser) {
    const payment = await this.prisma.payment.findUnique({
      where: { id },
      include: {
        engagement: {
          include: {
            institution: true,
          },
        },
        splits: true,
      },
    });

    if (!payment) {
      throw new NotFoundException('Pagamento nao encontrado.');
    }

    const canAccess =
      payment.engagement.institution.userId === user.userId ||
      payment.engagement.professionalUserId === user.userId;

    if (!canAccess) {
      throw new ForbiddenException('Voce nao pode visualizar este pagamento.');
    }

    return payment.provider === 'asaas' && this.asaasService.isEnabled()
      ? this.reconciliation.refresh(payment.id) : payment;
  }

  async findByEngagement(engagementId: string, user: AuthenticatedUser) {
    const payment = await this.prisma.payment.findUnique({
      where: {
        engagementId,
      },
      include: {
        engagement: {
          include: {
            institution: true,
          },
        },
        splits: true,
      },
    });

    if (!payment) {
      throw new NotFoundException('Pagamento nao encontrado para este fechamento.');
    }

    const canAccess =
      payment.engagement.institution.userId === user.userId ||
      payment.engagement.professionalUserId === user.userId;

    if (!canAccess) {
      throw new ForbiddenException('Voce nao pode visualizar este pagamento.');
    }

    return payment.provider === 'asaas' && this.asaasService.isEnabled()
      ? this.reconciliation.refresh(payment.id) : payment;
  }
}
