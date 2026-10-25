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
    required this.chargeAmountLabel,
    required this.gatewayFeeLabel,
    required this.clinicPaysGatewayFee,
    required this.isSandbox,
    required this.financialDivergence,
    required this.canRetryCharge,
    required this.professionalSplitLabel,
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
  final String chargeAmountLabel;
  final String gatewayFeeLabel;
  final bool clinicPaysGatewayFee;
  final bool isSandbox;
  final bool financialDivergence;
  final bool canRetryCharge;
  final String professionalSplitLabel;

  bool get isPaid => statusLabel == 'Pago';
  bool get isFailed => statusLabel == 'Falhou';
  bool get isConfirmed => isPaid || statusLabel == 'Autorizado';
  bool get canPay =>
      !financialDivergence && statusLabel == 'Aguardando pagamento';
  bool get hasCheckout =>
      canPay && checkoutUrl != null && checkoutUrl!.isNotEmpty;
  bool get isAsaas => providerLabel.toLowerCase() == 'asaas';
  bool get hasPixCopyPaste =>
      canPay && pixCopyPaste != null && pixCopyPaste!.trim().isNotEmpty;

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    final payload = json['providerPayload'];
    final providerPayload =
        payload is Map<String, dynamic> ? payload : const <String, dynamic>{};
    final pixCopyPaste = providerPayload['pixCopyPaste']?.toString();
    final splits = json['splits'];
    String professionalStatus = '';
    if (splits is List) {
      for (final split in splits) {
        if (split is Map && split['recipientType'] == 'PROFESSIONAL') {
          professionalStatus = split['status']?.toString() ?? '';
          break;
        }
      }
    }
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
      chargeAmountLabel: OpportunityFormatter.amountLabel(
          providerPayload['chargeAmount'] ?? json['grossAmount']),
      gatewayFeeLabel:
          OpportunityFormatter.amountLabel(providerPayload['gatewayFeeAmount']),
      clinicPaysGatewayFee:
          providerPayload['pricingModel'] == 'INSTITUTION_PAYS_GATEWAY_FEE',
      isSandbox: providerPayload['environment'] == 'sandbox' ||
          json['provider'] == 'sandbox-split',
      financialDivergence: providerPayload['financialDivergence'] == true ||
          json['providerStatus'] == 'RECONCILIATION_REQUIRED',
      canRetryCharge:
          json['status'] == 'FAILED' && json['providerPaymentId'] == null,
      professionalSplitLabel: switch (professionalStatus) {
        'TRANSFERRED' => 'Repasse concluído',
        'SCHEDULED' => 'Repasse agendado',
        'FAILED' => 'Repasse requer atenção',
        _ => 'Aguardando confirmação do repasse',
      },
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
      case 'PARTIALLY_REFUNDED':
        return 'Reembolsado parcialmente';
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
      case 'CREATING':
        return 'Gerando cobrança';
      case 'RECONCILIATION_REQUIRED':
        return 'Conciliação necessária';
      case 'PAYMENT_SPLIT_DIVERGENCE_BLOCK':
        return 'Split bloqueado por divergência';
      case 'PAYMENT_SPLIT_CANCELLED':
        return 'Split cancelado';
      case 'CHARGEBACK_REQUESTED':
      case 'CHARGEBACK_DISPUTE':
      case 'AWAITING_CHARGEBACK_REVERSAL':
        return 'Pagamento em contestação';
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
