import '../../../core/formatters/opportunity_formatter.dart';

class ApplicationSummary {
  const ApplicationSummary({
    required this.id,
    required this.statusLabel,
    required this.appliedAtLabel,
    required this.opportunityTitle,
    required this.institutionName,
    required this.specialtyLabel,
    required this.shiftLabel,
    required this.amountLabel,
  });

  final String id;
  final String statusLabel;
  final String appliedAtLabel;
  final String opportunityTitle;
  final String institutionName;
  final String specialtyLabel;
  final String shiftLabel;
  final String amountLabel;

  factory ApplicationSummary.fromJson(Map<String, dynamic> json) {
    final opportunity = json['opportunity'] as Map<String, dynamic>?;
    final institution = opportunity?['institution'] as Map<String, dynamic>?;
    final specialty = opportunity?['specialty'] as Map<String, dynamic>?;

    return ApplicationSummary(
      id: json['id']?.toString() ?? '',
      statusLabel: _statusLabel(json['status']?.toString() ?? ''),
      appliedAtLabel: _appliedAtLabel(json['appliedAt']?.toString() ?? ''),
      opportunityTitle:
          opportunity?['title']?.toString() ?? 'Oportunidade sem titulo',
      institutionName:
          institution?['tradeName']?.toString() ??
          institution?['legalName']?.toString() ??
          'Instituição',
      specialtyLabel:
          specialty?['name']?.toString() ?? 'Especialidade a definir',
      shiftLabel: OpportunityFormatter.shiftSummary(
        startAt: opportunity?['startAt']?.toString() ?? '',
        endAt: opportunity?['endAt']?.toString() ?? '',
      ),
      amountLabel: OpportunityFormatter.amountLabel(
        opportunity?['grossAmount'],
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'APPLIED':
        return 'Candidatura enviada';
      case 'ACCEPTED':
        return 'Aceita pela instituição';
      case 'REJECTED':
        return 'Não selecionada';
      case 'WITHDRAWN':
        return 'Retirada';
      default:
        return status.isEmpty ? 'Em analise' : status;
    }
  }

  static String _appliedAtLabel(String appliedAt) {
    final parsed = DateTime.tryParse(appliedAt)?.toLocal();
    if (parsed == null) {
      return 'Data de candidatura indisponível';
    }

    return 'Enviada em ${OpportunityFormatter.shortDate(parsed)} às ${OpportunityFormatter.hourLabel(parsed)}';
  }
}
