class AsaasAccountSummary {
  const AsaasAccountSummary({
    required this.environment,
    required this.accountStatus,
    required this.onboardingStatus,
    this.walletId,
    this.lastSynchronizedAt,
  });

  factory AsaasAccountSummary.fromJson(Map<String, dynamic> json) {
    return AsaasAccountSummary(
      environment: json['environment']?.toString() ?? 'SANDBOX',
      accountStatus: json['accountStatus']?.toString() ?? 'PENDING',
      onboardingStatus: json['onboardingStatus']?.toString() ?? 'NOT_STARTED',
      walletId: json['asaasWalletId']?.toString(),
      lastSynchronizedAt: DateTime.tryParse(
        json['lastSynchronizedAt']?.toString() ?? '',
      ),
    );
  }

  final String environment;
  final String accountStatus;
  final String onboardingStatus;
  final String? walletId;
  final DateTime? lastSynchronizedAt;

  String get statusLabel {
    switch (onboardingStatus) {
      case 'APPROVED':
        return 'Conta aprovada';
      case 'UNDER_REVIEW':
        return 'Em análise';
      case 'PENDING_DOCUMENTS':
        return 'Documentos pendentes';
      case 'PENDING_DATA':
        return 'Dados pendentes';
      case 'REJECTED':
        return 'Cadastro recusado';
      default:
        return 'Cadastro iniciado';
    }
  }

  String get environmentLabel =>
      environment == 'PRODUCTION' ? 'Produção' : 'Sandbox';

  String? get maskedWalletId {
    final value = walletId;
    if (value == null || value.isEmpty) {
      return null;
    }
    return value.length <= 8
        ? value
        : '••••${value.substring(value.length - 8)}';
  }
}
