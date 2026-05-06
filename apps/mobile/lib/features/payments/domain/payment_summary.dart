import '../../../core/formatters/opportunity_formatter.dart';

class PaymentSummary {
  const PaymentSummary({
    required this.id,
    required this.statusLabel,
    required this.providerLabel,
    required this.grossAmountLabel,
    required this.platformFeeLabel,
    required this.netAmountLabel,
    required this.paidAtLabel,
  });

  final String id;
  final String statusLabel;
  final String providerLabel;
  final String grossAmountLabel;
  final String platformFeeLabel;
  final String netAmountLabel;
  final String paidAtLabel;

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    return PaymentSummary(
      id: json['id']?.toString() ?? '',
      statusLabel: _statusLabel(json['status']?.toString() ?? ''),
      providerLabel: json['provider']?.toString() ?? 'manual-mvp',
      grossAmountLabel: OpportunityFormatter.amountLabel(json['grossAmount']),
      platformFeeLabel:
          OpportunityFormatter.amountLabel(json['platformFeeAmount']),
      netAmountLabel: OpportunityFormatter.amountLabel(json['netAmount']),
      paidAtLabel: _paidAtLabel(json['paidAt']?.toString() ?? ''),
    );
  }

  static String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return 'Pago';
      case 'PENDING':
        return 'Pendente';
      case 'FAILED':
        return 'Falhou';
      case 'REFUNDED':
        return 'Reembolsado';
      default:
        return status.isEmpty ? 'Sem status' : status;
    }
  }

  static String _paidAtLabel(String paidAt) {
    final parsed = DateTime.tryParse(paidAt)?.toLocal();
    if (parsed == null) {
      return 'Pagamento ainda sem data registrada';
    }

    return 'Pago em ${OpportunityFormatter.shortDate(parsed)} as ${OpportunityFormatter.hourLabel(parsed)}';
  }
}
