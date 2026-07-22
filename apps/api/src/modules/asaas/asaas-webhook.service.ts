import { Injectable } from '@nestjs/common';
import {
  AsaasAccountStatus,
  AsaasOnboardingStatus,
  AsaasWebhookProcessingStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';

type AsaasWebhookPayload = {
  id?: unknown;
  event?: unknown;
  account?: { id?: unknown };
  accountStatus?: { general?: unknown };
  payment?: { id?: unknown };
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
        return { received: true, duplicate: true };
      }
      throw error;
    }

    if (!eventType.startsWith('ACCOUNT_STATUS_') || !asaasAccountId) {
      await this.markEvent(
        webhookEvent.id,
        AsaasWebhookProcessingStatus.IGNORED,
      );
      return { received: true, ignored: true };
    }

    const generalStatus = this.optionalString(payload?.accountStatus?.general);
    const mappedStatus = this.mapAccountStatus(generalStatus);
    if (!mappedStatus) {
      await this.markEvent(
        webhookEvent.id,
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
        where: { id: webhookEvent.id },
        data: {
          processingStatus: AsaasWebhookProcessingStatus.PROCESSED,
          processedAt: new Date(),
        },
      }),
    ]);

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
