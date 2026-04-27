import '../../../core/formatters/opportunity_formatter.dart';

class OpportunityDetail {
  const OpportunityDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.institution,
    required this.specialty,
    required this.shiftLabel,
    required this.dateLabel,
    required this.durationLabel,
    required this.amountLabel,
    required this.urgencyLabel,
    required this.statusLabel,
    required this.locationLabel,
    required this.requiresVerifiedProfile,
    required this.applicantUserIds,
  });

  final String id;
  final String title;
  final String description;
  final String institution;
  final String specialty;
  final String shiftLabel;
  final String dateLabel;
  final String durationLabel;
  final String amountLabel;
  final String urgencyLabel;
  final String statusLabel;
  final String locationLabel;
  final bool requiresVerifiedProfile;
  final List<String> applicantUserIds;

  factory OpportunityDetail.fromJson(Map<String, dynamic> json) {
    final institution = json['institution'] as Map<String, dynamic>?;
    final specialty = json['specialty'] as Map<String, dynamic>?;
    final customSpecialtyLabel = json['customSpecialtyLabel']?.toString();
    final address = json['address'] as Map<String, dynamic>?;
    final applications = (json['applications'] as List<dynamic>? ?? const []);

    return OpportunityDetail(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Oportunidade sem titulo',
      description: json['description']?.toString() ?? 'Sem descricao informada.',
      institution:
          institution?['tradeName']?.toString() ??
          institution?['legalName']?.toString() ??
          'Instituicao',
      specialty: customSpecialtyLabel != null && customSpecialtyLabel.trim().isNotEmpty
          ? customSpecialtyLabel
          : specialty?['name']?.toString() ?? 'Especialidade a definir',
      shiftLabel: OpportunityFormatter.shiftSummary(
        startAt: json['startAt']?.toString() ?? '',
        endAt: json['endAt']?.toString() ?? '',
      ),
      dateLabel: OpportunityFormatter.dateHeadline(
        startAt: json['startAt']?.toString() ?? '',
        endAt: json['endAt']?.toString() ?? '',
      ),
      durationLabel: OpportunityFormatter.durationLabel(
        startAt: json['startAt']?.toString() ?? '',
        endAt: json['endAt']?.toString() ?? '',
      ),
      amountLabel: OpportunityFormatter.amountLabel(json['grossAmount']),
      urgencyLabel: OpportunityFormatter.urgencyLabel(
        json['urgencyLevel']?.toString() ?? '',
      ),
      statusLabel: OpportunityFormatter.statusLabel(json['status']?.toString() ?? ''),
      locationLabel: _buildLocationLabel(address),
      requiresVerifiedProfile: json['requiresVerifiedProfile'] == true,
      applicantUserIds: applications
          .whereType<Map<String, dynamic>>()
          .map((item) => item['professionalUserId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(),
    );
  }

  static String _buildLocationLabel(Map<String, dynamic>? address) {
    final parts = <String>[
      address?['city']?.toString() ?? '',
      address?['state']?.toString() ?? '',
    ].where((part) => part.isNotEmpty).toList();

    if (parts.isEmpty) {
      return 'Localizacao a confirmar';
    }

    return parts.join(' - ');
  }
}
