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
    required this.checkoutUrl,
    required this.providerStatusLabel,
    required this.pixCopyPaste,
  });

  final String id;
  final String statusLabel;
  final String providerLabel;
  final String grossAmountLabel;
  final String platformFeeLabel;
  final String netAmountLabel;
  final String paidAtLabel;
  final String? checkoutUrl;
  final String providerStatusLabel;
  final String? pixCopyPaste;

  bool get isPaid => statusLabel == 'Pago';
  bool get hasCheckout => checkoutUrl != null && checkoutUrl!.isNotEmpty;
  bool get isAsaas => providerLabel.toLowerCase() == 'asaas';
  bool get hasPixCopyPaste =>
      pixCopyPaste != null && pixCopyPaste!.trim().isNotEmpty;

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    final providerPayload = json['providerPayload'];
    final pixCopyPaste = providerPayload is Map<String, dynamic>
        ? providerPayload['pixCopyPaste']?.toString()
        : null;
    return PaymentSummary(
      id: json['id']?.toString() ?? '',
      statusLabel: _statusLabel(json['status']?.toString() ?? ''),
      providerLabel: json['provider']?.toString() ?? 'manual-mvp',
      grossAmountLabel: OpportunityFormatter.amountLabel(json['grossAmount']),
      platformFeeLabel:
          OpportunityFormatter.amountLabel(json['platformFeeAmount']),
      netAmountLabel: OpportunityFormatter.amountLabel(json['netAmount']),
      paidAtLabel: _paidAtLabel(json['paidAt']?.toString() ?? ''),
      checkoutUrl: json['checkoutUrl']?.toString(),
      providerStatusLabel:
          _providerStatusLabel(json['providerStatus']?.toString() ?? ''),
      pixCopyPaste: pixCopyPaste,
    );
  }

  static String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return 'Pago';
      case 'PENDING':
        return 'Aguardando pagamento';
      case 'AUTHORIZED':
        return 'Autorizado';
      case 'FAILED':
        return 'Falhou';
      case 'REFUNDED':
        return 'Reembolsado';
      default:
        return status.isEmpty ? 'Sem status' : status;
    }
  }

  static String _providerStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'CHECKOUT_CREATED':
        return 'Checkout criado';
      case 'PAID_SANDBOX':
        return 'Pago no sandbox';
      case 'PENDING':
        return 'Aguardando pagamento';
      case 'CONFIRMED':
        return 'Pagamento confirmado';
      case 'RECEIVED':
        return 'Pagamento recebido';
      case 'OVERDUE':
        return 'Cobrança vencida';
      case 'REFUNDED':
        return 'Pagamento estornado';
      case 'CREATE_FAILED':
        return 'Falha ao gerar cobrança';
      default:
        return status.isEmpty ? 'Sem retorno do provedor' : status;
    }
  }

  static String _paidAtLabel(String paidAt) {
    final parsed = DateTime.tryParse(paidAt)?.toLocal();
    if (parsed == null) {
      return 'Pagamento ainda sem data registrada';
    }

    return 'Pago em ${OpportunityFormatter.shortDate(parsed)} às ${OpportunityFormatter.hourLabel(parsed)}';
  }
}
