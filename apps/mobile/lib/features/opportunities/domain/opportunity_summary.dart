import '../../../core/formatters/opportunity_formatter.dart';

class OpportunitySummary {
  const OpportunitySummary({
    required this.id,
    required this.title,
    required this.institution,
    required this.specialty,
    required this.shiftLabel,
    required this.amountLabel,
    required this.distanceLabel,
    required this.urgencyLabel,
  });

  final String id;
  final String title;
  final String institution;
  final String specialty;
  final String shiftLabel;
  final String amountLabel;
  final String distanceLabel;
  final String urgencyLabel;

  factory OpportunitySummary.fromJson(Map<String, dynamic> json) {
    final institution = json['institution'] as Map<String, dynamic>?;
    final specialty = json['specialty'] as Map<String, dynamic>?;
    final customSpecialtyLabel = json['customSpecialtyLabel']?.toString();
    final amount = json['grossAmount'];
    final startAt = json['startAt']?.toString() ?? '';
    final endAt = json['endAt']?.toString() ?? '';
    final urgencyLevel = json['urgencyLevel']?.toString() ?? 'NORMAL';

    return OpportunitySummary(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Oportunidade sem titulo',
      institution:
          institution?['tradeName']?.toString() ??
          institution?['institutionType']?.toString() ??
          'Instituicao',
      specialty: customSpecialtyLabel != null && customSpecialtyLabel.trim().isNotEmpty
          ? customSpecialtyLabel
          : specialty?['name']?.toString() ?? 'Especialidade a definir',
      shiftLabel: OpportunityFormatter.shiftSummary(startAt: startAt, endAt: endAt),
      amountLabel: OpportunityFormatter.amountLabel(amount),
      distanceLabel: 'Proximidade em breve',
      urgencyLabel: OpportunityFormatter.urgencyLabel(urgencyLevel),
    );
  }
}
