import '../../../core/formatters/opportunity_formatter.dart';

class OpportunitySummary {
  const OpportunitySummary({
    required this.id,
    required this.title,
    required this.institution,
    required this.institutionReputationLabel,
    required this.opportunityType,
    required this.opportunityTypeLabel,
    required this.specialty,
    required this.shiftLabel,
    required this.amountLabel,
    required this.distanceLabel,
    required this.urgencyLabel,
  });

  final String id;
  final String title;
  final String institution;
  final String institutionReputationLabel;
  final String opportunityType;
  final String opportunityTypeLabel;
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
    final opportunityType = json['opportunityType']?.toString() ?? 'SHIFT';

    return OpportunitySummary(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Oportunidade sem titulo',
      institution: institution?['tradeName']?.toString() ??
          institution?['institutionType']?.toString() ??
          'Instituição',
      institutionReputationLabel: _reputationLabel(
        (institution?['user'] as Map<String, dynamic>?)?['reviewReceived'],
      ),
      opportunityType: opportunityType,
      opportunityTypeLabel: _opportunityTypeLabel(opportunityType),
      specialty:
          customSpecialtyLabel != null && customSpecialtyLabel.trim().isNotEmpty
              ? customSpecialtyLabel
              : specialty?['name']?.toString() ?? 'Especialidade a definir',
      shiftLabel:
          OpportunityFormatter.shiftSummary(startAt: startAt, endAt: endAt),
      amountLabel: OpportunityFormatter.amountLabel(amount),
      distanceLabel: 'Proximidade em breve',
      urgencyLabel: OpportunityFormatter.urgencyLabel(urgencyLevel),
    );
  }

  static String _opportunityTypeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'INTERNSHIP':
        return 'Estágio';
      case 'COVERAGE':
        return 'Cobertura';
      case 'TEMPORARY':
        return 'Temporario';
      case 'SHIFT':
        return 'Plantão';
      default:
        return 'Vaga';
    }
  }

  static String _reputationLabel(dynamic reviews) {
    if (reviews is! List || reviews.isEmpty) {
      return 'Instituição sem avaliações';
    }

    final ratings = reviews
        .whereType<Map<String, dynamic>>()
        .map((review) => int.tryParse(review['rating']?.toString() ?? '') ?? 0)
        .where((rating) => rating > 0)
        .toList();

    if (ratings.isEmpty) {
      return 'Instituição sem avaliações';
    }

    final average =
        ratings.reduce((sum, rating) => sum + rating) / ratings.length;
    final countLabel =
        ratings.length == 1 ? '1 avaliação' : '${ratings.length} avaliações';

    return '★ ${average.toStringAsFixed(1)} ($countLabel)';
  }
}
