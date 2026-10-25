import 'package:flutter_test/flutter_test.dart';

import 'package:vetfinder_mobile/features/payments/domain/payment_quote.dart';
import 'package:vetfinder_mobile/features/payments/domain/payment_summary.dart';

void main() {
  Map<String, dynamic> quote() => {
        'serviceAmount': 250,
        'subtotalAmount': 257.5,
        'chargeAmount': 259.49,
        'gatewayFeeAmount': 1.99,
        'platformFeeAmount': 7.5,
        'professionalAmount': 250,
        'gatewayFeePayer': 'INSTITUTION',
        'platformFeePayer': 'INSTITUTION',
        'environment': 'sandbox',
      };

  Map<String, dynamic> payment() => {
        'id': 'payment-test',
        'provider': 'asaas',
        'providerPaymentId': 'pay_test',
        'status': 'PENDING',
        'providerStatus': 'PENDING',
        'grossAmount': '257.50',
        'platformFeeAmount': '7.50',
        'netAmount': '250.00',
        'checkoutUrl': 'https://example.test/invoice',
        'providerPayload': {
          ...quote(),
          'pricingModel': 'INSTITUTION_PAYS_GATEWAY_FEE',
          'pixCopyPaste': 'test-pix',
        },
        'splits': [
          {'recipientType': 'PROFESSIONAL', 'status': 'SCHEDULED'},
        ],
      };

  test('quote keeps the service split separate from the clinic total', () {
    final result = PaymentQuote.fromJson(quote());
    expect(result.serviceAmount, 250);
    expect(result.subtotalAmount, 257.5);
    expect(result.chargeAmount, 259.49);
    expect(result.professionalAmount, 250);
    expect(result.platformFeeAmount, 7.5);
    expect(result.gatewayFeeAmount, 1.99);
    expect(result.isSandbox, isTrue);
  });

  test('an absent fee or inconsistent total cannot be approved', () {
    expect(() => PaymentQuote.fromJson(quote()..remove('gatewayFeeAmount')),
        throwsFormatException);
    expect(() => PaymentQuote.fromJson({...quote(), 'chargeAmount': 180}),
        throwsFormatException);
    expect(() => PaymentQuote.fromJson({...quote(), 'professionalAmount': 170}),
        throwsFormatException);
    expect(
        () => PaymentQuote.fromJson(
            {...quote(), 'gatewayFeePayer': 'PROFESSIONAL'}),
        throwsFormatException);
  });

  test('pending charges are not paid or confirmed contracts', () {
    final result = PaymentSummary.fromJson(payment());
    expect(result.isConfirmed, isFalse);
    expect(result.hasCheckout, isTrue);
    expect(result.hasPixCopyPaste, isTrue);
    expect(result.clinicPaysGatewayFee, isTrue);
    expect(result.professionalSplitLabel, 'Repasse agendado');
  });

  test(
      'a quote cannot deduct commission from the requested professional amount',
      () {
    expect(
        () => PaymentQuote.fromJson({
              ...quote(),
              'professionalAmount': 242.5,
              'subtotalAmount': 250,
              'chargeAmount': 251.99,
            }),
        throwsFormatException);
  });

  test('paid charges do not display a second Pix payment action', () {
    final result = PaymentSummary.fromJson({...payment(), 'status': 'PAID'});
    expect(result.isPaid, isTrue);
    expect(result.isConfirmed, isTrue);
    expect(result.hasCheckout, isFalse);
    expect(result.hasPixCopyPaste, isFalse);
    expect(result.canRetryCharge, isFalse);
  });

  test('a failed charge with a remote ID cannot be charged again', () {
    expect(
        PaymentSummary.fromJson({...payment(), 'status': 'FAILED'})
            .canRetryCharge,
        isFalse);
    expect(
        PaymentSummary.fromJson({
          ...payment(),
          'status': 'FAILED',
          'providerPaymentId': null,
        }).canRetryCharge,
        isTrue);
  });

  test('divergent charges hide payment actions and require reconciliation', () {
    final data = payment();
    (data['providerPayload'] as Map<String, dynamic>)['financialDivergence'] =
        true;
    final result = PaymentSummary.fromJson(data);
    expect(result.financialDivergence, isTrue);
    expect(result.hasCheckout, isFalse);
    expect(result.hasPixCopyPaste, isFalse);
  });

  test('split settlement and partial refunds are displayed independently', () {
    final result = PaymentSummary.fromJson({
      ...payment(),
      'status': 'PARTIALLY_REFUNDED',
      'splits': [
        {'recipientType': 'PROFESSIONAL', 'status': 'TRANSFERRED'}
      ],
    });
    expect(result.statusLabel, 'Reembolsado parcialmente');
    expect(result.professionalSplitLabel, 'Repasse conclu\u00eddo');
    expect(result.hasPixCopyPaste, isFalse);
  });
}
