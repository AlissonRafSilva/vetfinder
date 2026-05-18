import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

type CreatePaymentIntentInput = {
  engagementId: string;
  grossAmount: unknown;
  platformFeeAmount: unknown;
  netAmount: unknown;
};

type PaymentIntent = {
  provider: string;
  providerPaymentId: string;
  providerStatus: string;
  checkoutUrl: string;
  providerPayload: Prisma.InputJsonObject;
};

@Injectable()
export class PaymentProvider {
  createPaymentIntent(input: CreatePaymentIntentInput): PaymentIntent {
    const providerPaymentId = `sandbox_${input.engagementId}_${Date.now()}`;

    return {
      provider: 'sandbox-split',
      providerPaymentId,
      providerStatus: 'CHECKOUT_CREATED',
      checkoutUrl: `https://sandbox.vetfinder.local/checkout/${providerPaymentId}`,
      providerPayload: {
        mode: 'sandbox',
        grossAmount: input.grossAmount?.toString(),
        platformFeeAmount: input.platformFeeAmount?.toString(),
        netAmount: input.netAmount?.toString(),
        split: {
          platform: input.platformFeeAmount?.toString(),
          professional: input.netAmount?.toString(),
        },
      },
    };
  }
}
