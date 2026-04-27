import '../../../core/formatters/opportunity_formatter.dart';

class InviteSummary {
  const InviteSummary({
    required this.id,
    required this.statusLabel,
    required this.invitedAtLabel,
    required this.opportunityTitle,
    required this.institutionName,
    required this.specialtyLabel,
    required this.shiftLabel,
    required this.amountLabel,
    required this.message,
  });

  final String id;
  final String statusLabel;
  final String invitedAtLabel;
  final String opportunityTitle;
  final String institutionName;
  final String specialtyLabel;
  final String shiftLabel;
  final String amountLabel;
  final String? message;

  bool get canRespond => statusLabel == 'Convite recebido';

  factory InviteSummary.fromJson(Map<String, dynamic> json) {
    final opportunity = json['opportunity'] as Map<String, dynamic>?;
    final institution = opportunity?['institution'] as Map<String, dynamic>?;
    final specialty = opportunity?['specialty'] as Map<String, dynamic>?;

    return InviteSummary(
      id: json['id']?.toString() ?? '',
      statusLabel: _statusLabel(json['status']?.toString() ?? ''),
      invitedAtLabel: _invitedAtLabel(json['invitedAt']?.toString() ?? ''),
      opportunityTitle:
          opportunity?['title']?.toString() ?? 'Oportunidade sem titulo',
      institutionName:
          institution?['tradeName']?.toString() ??
          institution?['legalName']?.toString() ??
          'Instituicao',
      specialtyLabel:
          specialty?['name']?.toString() ?? 'Especialidade a definir',
      shiftLabel: OpportunityFormatter.shiftSummary(
        startAt: opportunity?['startAt']?.toString() ?? '',
        endAt: opportunity?['endAt']?.toString() ?? '',
      ),
      amountLabel: OpportunityFormatter.amountLabel(
        opportunity?['grossAmount'],
      ),
      message: json['message']?.toString(),
    );
  }

  static String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'SENT':
        return 'Convite recebido';
      case 'ACCEPTED':
        return 'Convite aceito';
      case 'DECLINED':
        return 'Convite recusado';
      default:
        return status.isEmpty ? 'Em aberto' : status;
    }
  }

  static String _invitedAtLabel(String invitedAt) {
    final parsed = DateTime.tryParse(invitedAt)?.toLocal();
    if (parsed == null) {
      return 'Data do convite indisponivel';
    }

    return 'Recebido em ${OpportunityFormatter.shortDate(parsed)} as ${OpportunityFormatter.hourLabel(parsed)}';
  }
}
