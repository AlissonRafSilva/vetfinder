import '../../../core/formatters/opportunity_formatter.dart';

class PaymentQuote {
  const PaymentQuote({
    required this.serviceAmount,
    required this.subtotalAmount,
    required this.chargeAmount,
    required this.gatewayFeeAmount,
    required this.platformFeeAmount,
    required this.professionalAmount,
    required this.isSandbox,
  });

  final double serviceAmount;
  final double subtotalAmount;
  final double chargeAmount;
  final double gatewayFeeAmount;
  final double platformFeeAmount;
  final double professionalAmount;
  final bool isSandbox;

  String get serviceAmountLabel =>
      OpportunityFormatter.amountLabel(serviceAmount);
  String get chargeAmountLabel =>
      OpportunityFormatter.amountLabel(chargeAmount);
  String get gatewayFeeLabel =>
      OpportunityFormatter.amountLabel(gatewayFeeAmount);
  String get platformFeeLabel =>
      OpportunityFormatter.amountLabel(platformFeeAmount);
  String get professionalAmountLabel =>
      OpportunityFormatter.amountLabel(professionalAmount);

  factory PaymentQuote.fromJson(Map<String, dynamic> json) {
    double amount(String key) {
      final value = double.tryParse(json[key]?.toString() ?? '');
      if (value == null || !value.isFinite || value < 0) {
        throw const FormatException('Cotacao de pagamento invalida.');
      }
      return value;
    }

    final service = amount('serviceAmount');
    final subtotal = amount('subtotalAmount');
    final charge = amount('chargeAmount');
    final fee = amount('gatewayFeeAmount');
    final platform = amount('platformFeeAmount');
    final professional = amount('professionalAmount');
    int cents(double value) => (value * 100).round();
    if (service <= 0 ||
        cents(service) != cents(professional) ||
        cents(charge) != cents(subtotal) + cents(fee) ||
        cents(subtotal) != cents(platform) + cents(professional) ||
        json['gatewayFeePayer'] != 'INSTITUTION' ||
        json['platformFeePayer'] != 'INSTITUTION' ||
        !['sandbox', 'production'].contains(json['environment'])) {
      throw const FormatException('Cotacao de pagamento inconsistente.');
    }

    return PaymentQuote(
      serviceAmount: service,
      subtotalAmount: subtotal,
      chargeAmount: charge,
      gatewayFeeAmount: fee,
      platformFeeAmount: platform,
      professionalAmount: professional,
      isSandbox: json['environment'] == 'sandbox',
    );
  }
}
