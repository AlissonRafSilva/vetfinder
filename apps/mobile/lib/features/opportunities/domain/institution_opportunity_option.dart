import '../../../core/formatters/opportunity_formatter.dart';

class InstitutionOpportunityOption {
  const InstitutionOpportunityOption({
    required this.id,
    required this.title,
    required this.description,
    required this.opportunityType,
    required this.customSpecialtyLabel,
    required this.statusValue,
    required this.statusLabel,
    required this.shiftLabel,
    required this.amountLabel,
    required this.specialtyLabel,
    required this.startAt,
    required this.endAt,
    required this.grossAmount,
    required this.urgencyLevel,
    required this.requiresVerifiedProfile,
    required this.durationHours,
  });

  final String id;
  final String title;
  final String description;
  final String opportunityType;
  final String? customSpecialtyLabel;
  final String statusValue;
  final String statusLabel;
  final String shiftLabel;
  final String amountLabel;
  final String specialtyLabel;
  final String startAt;
  final String endAt;
  final num? grossAmount;
  final String urgencyLevel;
  final bool requiresVerifiedProfile;
  final num? durationHours;

  factory InstitutionOpportunityOption.fromJson(Map<String, dynamic> json) {
    final specialty = json['specialty'] as Map<String, dynamic>?;
    final grossAmount = _parseNum(json['grossAmount']);
    final durationHours = _parseNum(json['durationHours']);
    final customSpecialtyLabel = json['customSpecialtyLabel']?.toString();

    return InstitutionOpportunityOption(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Vaga sem titulo',
      description: json['description']?.toString() ?? '',
      opportunityType: json['opportunityType']?.toString() ?? 'SHIFT',
      customSpecialtyLabel: customSpecialtyLabel,
      statusValue: json['status']?.toString() ?? '',
      statusLabel:
          OpportunityFormatter.statusLabel(json['status']?.toString() ?? ''),
      shiftLabel: OpportunityFormatter.shiftSummary(
        startAt: json['startAt']?.toString() ?? '',
        endAt: json['endAt']?.toString() ?? '',
      ),
      amountLabel: OpportunityFormatter.amountLabel(grossAmount),
      specialtyLabel:
          customSpecialtyLabel != null && customSpecialtyLabel.trim().isNotEmpty
              ? customSpecialtyLabel
              : specialty?['name']?.toString() ?? 'Especialidade a definir',
      startAt: json['startAt']?.toString() ?? '',
      endAt: json['endAt']?.toString() ?? '',
      grossAmount: grossAmount,
      urgencyLevel: json['urgencyLevel']?.toString() ?? 'MEDIUM',
      requiresVerifiedProfile: json['requiresVerifiedProfile'] as bool? ?? true,
      durationHours: durationHours,
    );
  }

  static num? _parseNum(dynamic value) {
    if (value is num) {
      return value;
    }

    if (value is String) {
      return num.tryParse(value);
    }

    return null;
  }
}
