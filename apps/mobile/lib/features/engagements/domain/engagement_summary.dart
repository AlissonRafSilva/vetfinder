import '../../../core/formatters/opportunity_formatter.dart';

class EngagementSummary {
  const EngagementSummary({
    required this.id,
    required this.opportunityTitle,
    required this.professionalName,
    required this.professionalEmail,
    required this.professionalRoleLabel,
    required this.institutionName,
    required this.specialtyLabel,
    required this.shiftLabel,
    required this.grossAmountLabel,
    required this.platformFeeLabel,
    required this.netAmountLabel,
    required this.statusLabel,
    required this.sourceLabel,
    required this.createdAtLabel,
  });

  final String id;
  final String opportunityTitle;
  final String professionalName;
  final String professionalEmail;
  final String professionalRoleLabel;
  final String institutionName;
  final String specialtyLabel;
  final String shiftLabel;
  final String grossAmountLabel;
  final String platformFeeLabel;
  final String netAmountLabel;
  final String statusLabel;
  final String sourceLabel;
  final String createdAtLabel;

  factory EngagementSummary.fromJson(Map<String, dynamic> json) {
    final opportunity = json['opportunity'] as Map<String, dynamic>?;
    final specialty = opportunity?['specialty'] as Map<String, dynamic>?;
    final professional = json['professional'] as Map<String, dynamic>?;
    final profile = professional?['profile'] as Map<String, dynamic>?;
    final institution = json['institution'] as Map<String, dynamic>?;
    final customSpecialtyLabel =
        opportunity?['customSpecialtyLabel']?.toString();

    return EngagementSummary(
      id: json['id']?.toString() ?? '',
      opportunityTitle: opportunity?['title']?.toString() ?? 'Plantão fechado',
      professionalName: profile?['fullName']?.toString() ??
          professional?['email']?.toString() ??
          'Profissional',
      professionalEmail: professional?['email']?.toString() ?? '',
      professionalRoleLabel:
          _roleLabel(professional?['role']?.toString() ?? ''),
      institutionName: institution?['tradeName']?.toString() ??
          institution?['legalName']?.toString() ??
          'Instituição',
      specialtyLabel:
          customSpecialtyLabel != null && customSpecialtyLabel.trim().isNotEmpty
              ? customSpecialtyLabel
              : specialty?['name']?.toString() ?? 'Especialidade a definir',
      shiftLabel: OpportunityFormatter.shiftSummary(
        startAt: opportunity?['startAt']?.toString() ?? '',
        endAt: opportunity?['endAt']?.toString() ?? '',
      ),
      grossAmountLabel: OpportunityFormatter.amountLabel(json['grossAmount']),
      platformFeeLabel:
          OpportunityFormatter.amountLabel(json['platformFeeAmount']),
      netAmountLabel: OpportunityFormatter.amountLabel(json['netAmount']),
      statusLabel: _statusLabel(json['status']?.toString() ?? ''),
      sourceLabel: _sourceLabel(json['sourceType']?.toString() ?? ''),
      createdAtLabel: _createdAtLabel(json['createdAt']?.toString() ?? ''),
    );
  }

  static String _roleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'VETERINARIAN':
        return 'Veterinario volante';
      case 'INTERN':
        return 'Estagiario';
      default:
        return 'Profissional';
    }
  }

  static String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING_PAYMENT':
        return 'Aguardando pagamento';
      case 'CONFIRMED':
        return 'Confirmado';
      case 'IN_PROGRESS':
        return 'Em andamento';
      case 'COMPLETED':
        return 'Concluido';
      case 'CANCELLED':
        return 'Cancelado';
      case 'DISPUTED':
        return 'Em disputa';
      default:
        return status.isEmpty ? 'Fechado' : status;
    }
  }

  static String _sourceLabel(String sourceType) {
    switch (sourceType.toUpperCase()) {
      case 'APPLICATION':
        return 'Origem: candidatura';
      case 'INVITE':
        return 'Origem: convite';
      default:
        return 'Origem não identificada';
    }
  }

  static String _createdAtLabel(String createdAt) {
    final parsed = DateTime.tryParse(createdAt)?.toLocal();
    if (parsed == null) {
      return 'Data de fechamento indisponivel';
    }

    return 'Fechado em ${OpportunityFormatter.shortDate(parsed)} às ${OpportunityFormatter.hourLabel(parsed)}';
  }
}
