import { PaymentStatus, SplitStatus } from '@prisma/client';

export function asaasPaymentStatus(current: PaymentStatus, status: string) {
  const incoming = (() => {
    switch (status) {
      case 'RECEIVED':
        return PaymentStatus.PAID;
      case 'CONFIRMED':
      case 'AUTHORIZED':
        return PaymentStatus.AUTHORIZED;
      case 'REFUNDED':
        return PaymentStatus.REFUNDED;
      case 'PARTIALLY_REFUNDED':
        return PaymentStatus.PARTIALLY_REFUNDED;
      case 'OVERDUE':
      case 'DELETED':
      case 'CREDIT_CARD_CAPTURE_REFUSED':
      case 'CHARGEBACK_REQUESTED':
      case 'CHARGEBACK_DISPUTE':
      case 'AWAITING_CHARGEBACK_REVERSAL':
        return PaymentStatus.FAILED;
      default:
        return PaymentStatus.PENDING;
    }
  })();

  if (current === PaymentStatus.REFUNDED) return current;
  if (
    current === PaymentStatus.PARTIALLY_REFUNDED &&
    incoming !== PaymentStatus.REFUNDED
  ) return current;
  if (status.includes('CHARGEBACK')) return incoming;
  if (
    current === PaymentStatus.PAID &&
    incoming !== PaymentStatus.REFUNDED &&
    incoming !== PaymentStatus.PARTIALLY_REFUNDED
  ) return current;
  if (
    current === PaymentStatus.AUTHORIZED &&
    (incoming === PaymentStatus.PENDING || incoming === PaymentStatus.FAILED)
  ) return current;

  return incoming;
}

export function asaasSplitStatus(input: {
  current: SplitStatus;
  paymentStatus: PaymentStatus;
  providerStatus?: string;
  eventType?: string;
  splitDone?: boolean;
  authoritative?: boolean;
}) {
  if (
    input.paymentStatus === PaymentStatus.REFUNDED ||
    input.paymentStatus === PaymentStatus.PARTIALLY_REFUNDED ||
    input.eventType?.includes('CHARGEBACK') ||
    input.eventType === 'PAYMENT_SPLIT_CANCELLED' ||
    input.eventType === 'PAYMENT_SPLIT_DIVERGENCE_BLOCK' ||
    ['CANCELLED', 'REFUSED', 'REFUNDED'].includes(input.providerStatus ?? '')
  ) return SplitStatus.FAILED;

  if (input.providerStatus === 'DONE' || input.splitDone) {
    return SplitStatus.TRANSFERRED;
  }
  if (input.current === SplitStatus.TRANSFERRED) return input.current;
  if (input.current === SplitStatus.FAILED && !input.authoritative) {
    return input.current;
  }
  if (
    input.providerStatus === 'AWAITING_CREDIT' ||
    input.paymentStatus === PaymentStatus.PAID ||
    input.paymentStatus === PaymentStatus.AUTHORIZED
  ) return SplitStatus.SCHEDULED;

  return SplitStatus.PENDING;
}
