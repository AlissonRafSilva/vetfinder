import { Injectable } from '@nestjs/common';
import {
  AsaasAccountStatus,
  AsaasOnboardingStatus,
  AsaasWebhookProcessingStatus,
  Prisma,
} from '@prisma/client';
import { isUUID } from 'class-validator';
import { PrismaService } from '../../common/database/prisma.service';
import { AsaasPaymentReconciliationService } from './asaas-payment-reconciliation.service';
import { AsaasChargeResponse } from './asaas.service';

type AsaasWebhookPayload = {
  id?: unknown;
  event?: unknown;
  account?: { id?: unknown };
  accountStatus?: { general?: unknown };
  payment?: AsaasChargeResponse;
  additionalInfo?: { splitId?: unknown };
};

@Injectable()
export class AsaasWebhookService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly reconciliation: AsaasPaymentReconciliationService,
  ) {}

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
        webhookEvent = existing;
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
      await this.prisma.asaasWebhookEvent.updateMany({
        where: {
          id: webhookEvent.id,
          processingStatus: { not: AsaasWebhookProcessingStatus.PROCESSED },
        },
        data: { processingStatus: AsaasWebhookProcessingStatus.FAILED },
      });
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
    const supported = new Set([
      'PAYMENT_CREATED', 'PAYMENT_UPDATED', 'PAYMENT_RESTORED',
      'PAYMENT_AUTHORIZED', 'PAYMENT_CONFIRMED', 'PAYMENT_RECEIVED',
      'PAYMENT_OVERDUE', 'PAYMENT_DELETED', 'PAYMENT_REFUNDED',
      'PAYMENT_PARTIALLY_REFUNDED', 'PAYMENT_CREDIT_CARD_CAPTURE_REFUSED',
      'PAYMENT_CHARGEBACK_REQUESTED', 'PAYMENT_CHARGEBACK_DISPUTE',
      'PAYMENT_AWAITING_CHARGEBACK_REVERSAL', 'PAYMENT_SPLIT_CANCELLED',
      'PAYMENT_SPLIT_DONE', 'PAYMENT_SPLIT_DIVERGENCE_BLOCK',
      'PAYMENT_SPLIT_DIVERGENCE_BLOCK_FINISHED',
    ]);
    if (!supported.has(eventType) || !payload.payment) {
      await this.markEvent(webhookEventId, AsaasWebhookProcessingStatus.IGNORED);
      return { received: true, ignored: true };
    }

    const reference = this.optionalString(payload.payment.externalReference);
    const payment = await this.prisma.payment.findFirst({
      where: {
        provider: 'asaas',
        OR: [
          { providerPaymentId },
          ...(reference && isUUID(reference) ? [{ id: reference }] : []),
        ],
      },
      select: { id: true },
    });
    if (!payment) {
      await this.markEvent(webhookEventId, AsaasWebhookProcessingStatus.IGNORED);
      return { received: true, ignored: true };
    }

    await this.reconciliation.applyCharge(payment.id, payload.payment, {
      eventType,
      webhookEventId,
      splitId: this.optionalString(payload.additionalInfo?.splitId),
    });
    return { received: true };
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
