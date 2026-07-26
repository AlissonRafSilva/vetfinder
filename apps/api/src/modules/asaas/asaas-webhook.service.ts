import { Injectable } from '@nestjs/common';
import {
  AsaasAccountStatus,
  AsaasOnboardingStatus,
  AsaasWebhookProcessingStatus,
  EngagementStatus,
  PaymentStatus,
  Prisma,
  SplitStatus,
} from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';

type AsaasWebhookPayload = {
  id?: unknown;
  event?: unknown;
  account?: { id?: unknown };
  accountStatus?: { general?: unknown };
  payment?: { id?: unknown; status?: unknown };
};

@Injectable()
export class AsaasWebhookService {
  constructor(private readonly prisma: PrismaService) {}

  async receive(input: unknown) {
    const payload = input as AsaasWebhookPayload;
    const eventId = this.requiredString(payload?.id);
    const eventType = this.requiredString(payload?.event);
    const asaasAccountId = this.optionalString(payload?.account?.id);
    const providerPaymentId = this.optionalString(payload?.payment?.id);

    if (!eventId || !eventType) {
      return { received: false, reason: 'invalid_payload' };
    }

    let webhookEvent;
    try {
      webhookEvent = await this.prisma.asaasWebhookEvent.create({
        data: {
          asaasEventId: eventId,
          eventType,
          asaasAccountId,
          providerPaymentId,
        },
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        const existing = await this.prisma.asaasWebhookEvent.findUnique({
          where: { asaasEventId: eventId },
        });
        if (
          !existing ||
          existing.processingStatus ===
            AsaasWebhookProcessingStatus.PROCESSED ||
          existing.processingStatus === AsaasWebhookProcessingStatus.IGNORED
        ) {
          return { received: true, duplicate: true };
        }
        webhookEvent = await this.prisma.asaasWebhookEvent.update({
          where: { id: existing.id },
          data: {
            processingStatus: AsaasWebhookProcessingStatus.RECEIVED,
            processedAt: null,
          },
        });
      } else {
        throw error;
      }
    }

    try {
      if (eventType.startsWith('ACCOUNT_STATUS_') && asaasAccountId) {
        return await this.processAccountStatus(
          webhookEvent.id,
          asaasAccountId,
          payload,
        );
      }

      if (eventType.startsWith('PAYMENT_') && providerPaymentId) {
        return await this.processPayment(
          webhookEvent.id,
          eventType,
          providerPaymentId,
          payload,
        );
      }

      await this.markEvent(
        webhookEvent.id,
        AsaasWebhookProcessingStatus.IGNORED,
      );
      return { received: true, ignored: true };
    } catch (error) {
      await this.markEvent(
        webhookEvent.id,
        AsaasWebhookProcessingStatus.FAILED,
      );
      throw error;
    }
  }

  private async processAccountStatus(
    webhookEventId: string,
    asaasAccountId: string,
    payload: AsaasWebhookPayload,
  ) {
    const generalStatus = this.optionalString(payload?.accountStatus?.general);
    const mappedStatus = this.mapAccountStatus(generalStatus);
    if (!mappedStatus) {
      await this.markEvent(
        webhookEventId,
        AsaasWebhookProcessingStatus.IGNORED,
      );
      return { received: true, ignored: true };
    }

    await this.prisma.$transaction([
      this.prisma.asaasAccount.updateMany({
        where: { asaasAccountId },
        data: {
          ...mappedStatus,
          lastSynchronizedAt: new Date(),
        },
      }),
      this.prisma.asaasWebhookEvent.update({
        where: { id: webhookEventId },
        data: {
          processingStatus: AsaasWebhookProcessingStatus.PROCESSED,
          processedAt: new Date(),
        },
      }),
    ]);

    return { received: true };
  }

  private async processPayment(
    webhookEventId: string,
    eventType: string,
    providerPaymentId: string,
    payload: AsaasWebhookPayload,
  ) {
    const payment = await this.prisma.payment.findFirst({
      where: { providerPaymentId },
      select: { id: true, engagementId: true },
    });
    if (!payment) {
      await this.markEvent(
        webhookEventId,
        AsaasWebhookProcessingStatus.IGNORED,
      );
      return { received: true, ignored: true };
    }

    const providerStatus =
      this.optionalString(payload.payment?.status) ?? eventType;
    if (eventType === 'PAYMENT_RECEIVED') {
      await this.prisma.$transaction([
        this.prisma.payment.update({
          where: { id: payment.id },
          data: {
            status: PaymentStatus.PAID,
            providerStatus,
            paidAt: new Date(),
          },
        }),
        this.prisma.paymentSplit.updateMany({
          where: { paymentId: payment.id },
          data: { status: SplitStatus.SCHEDULED },
        }),
        this.prisma.engagement.update({
          where: { id: payment.engagementId },
          data: {
            status: EngagementStatus.CONFIRMED,
            confirmedAt: new Date(),
          },
        }),
        this.processedEventUpdate(webhookEventId),
      ]);
      return { received: true };
    }

    if (eventType === 'PAYMENT_CONFIRMED') {
      await this.prisma.$transaction([
        this.prisma.payment.update({
          where: { id: payment.id },
          data: {
            status: PaymentStatus.AUTHORIZED,
            providerStatus,
          },
        }),
        this.prisma.engagement.update({
          where: { id: payment.engagementId },
          data: {
            status: EngagementStatus.CONFIRMED,
            confirmedAt: new Date(),
          },
        }),
        this.processedEventUpdate(webhookEventId),
      ]);
      return { received: true };
    }

    if (eventType === 'PAYMENT_REFUNDED') {
      await this.prisma.$transaction([
        this.prisma.payment.update({
          where: { id: payment.id },
          data: {
            status: PaymentStatus.REFUNDED,
            providerStatus,
            refundedAt: new Date(),
          },
        }),
        this.processedEventUpdate(webhookEventId),
      ]);
      return { received: true };
    }

    if (eventType === 'PAYMENT_PARTIALLY_REFUNDED') {
      await this.prisma.$transaction([
        this.prisma.payment.update({
          where: { id: payment.id },
          data: {
            status: PaymentStatus.PARTIALLY_REFUNDED,
            providerStatus,
            refundedAt: new Date(),
          },
        }),
        this.processedEventUpdate(webhookEventId),
      ]);
      return { received: true };
    }

    if (
      eventType === 'PAYMENT_OVERDUE' ||
      eventType === 'PAYMENT_DELETED' ||
      eventType === 'PAYMENT_CREDIT_CARD_CAPTURE_REFUSED'
    ) {
      await this.prisma.$transaction([
        this.prisma.payment.update({
          where: { id: payment.id },
          data: {
            status: PaymentStatus.FAILED,
            providerStatus,
          },
        }),
        this.processedEventUpdate(webhookEventId),
      ]);
      return { received: true };
    }

    if (
      eventType === 'PAYMENT_SPLIT_CANCELLED' ||
      eventType === 'PAYMENT_SPLIT_DIVERGENCE_BLOCK'
    ) {
      await this.prisma.$transaction([
        this.prisma.payment.update({
          where: { id: payment.id },
          data: { providerStatus },
        }),
        this.prisma.paymentSplit.updateMany({
          where: { paymentId: payment.id },
          data: { status: SplitStatus.FAILED },
        }),
        this.processedEventUpdate(webhookEventId),
      ]);
      return { received: true };
    }

    await this.markEvent(
      webhookEventId,
      AsaasWebhookProcessingStatus.IGNORED,
    );
    return { received: true, ignored: true };
  }

  private processedEventUpdate(id: string) {
    return this.prisma.asaasWebhookEvent.update({
      where: { id },
      data: {
        processingStatus: AsaasWebhookProcessingStatus.PROCESSED,
        processedAt: new Date(),
      },
    });
  }

  private mapAccountStatus(generalStatus?: string) {
    switch (generalStatus) {
      case 'APPROVED':
        return {
          accountStatus: AsaasAccountStatus.ACTIVE,
          onboardingStatus: AsaasOnboardingStatus.APPROVED,
        };
      case 'REJECTED':
        return {
          accountStatus: AsaasAccountStatus.REJECTED,
          onboardingStatus: AsaasOnboardingStatus.REJECTED,
        };
      case 'AWAITING_APPROVAL':
        return {
          accountStatus: AsaasAccountStatus.PENDING,
          onboardingStatus: AsaasOnboardingStatus.UNDER_REVIEW,
        };
      case 'PENDING':
        return {
          accountStatus: AsaasAccountStatus.PENDING,
          onboardingStatus: AsaasOnboardingStatus.PENDING_DOCUMENTS,
        };
      default:
        return null;
    }
  }

  private markEvent(
    id: string,
    processingStatus: AsaasWebhookProcessingStatus,
  ) {
    return this.prisma.asaasWebhookEvent.update({
      where: { id },
      data: { processingStatus, processedAt: new Date() },
    });
  }

  private requiredString(value: unknown) {
    return typeof value === 'string' && value.trim() ? value.trim() : null;
  }

  private optionalString(value: unknown) {
    return typeof value === 'string' && value.trim()
      ? value.trim()
      : undefined;
  }
}
