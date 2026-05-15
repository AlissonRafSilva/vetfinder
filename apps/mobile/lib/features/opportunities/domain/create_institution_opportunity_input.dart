class CreateInstitutionOpportunityInput {
  const CreateInstitutionOpportunityInput({
    required this.title,
    required this.description,
    required this.opportunityType,
    this.customSpecialtyLabel,
    required this.startAt,
    required this.endAt,
    required this.grossAmount,
    this.durationHours,
    this.urgencyLevel = 'MEDIUM',
    this.requiresVerifiedProfile = false,
  });

  final String title;
  final String description;
  final String opportunityType;
  final String? customSpecialtyLabel;
  final DateTime startAt;
  final DateTime endAt;
  final double grossAmount;
  final double? durationHours;
  final String urgencyLevel;
  final bool requiresVerifiedProfile;

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'opportunityType': opportunityType,
      if (customSpecialtyLabel != null && customSpecialtyLabel!.trim().isNotEmpty)
        'customSpecialtyLabel': customSpecialtyLabel!.trim(),
      'startAt': startAt.toUtc().toIso8601String(),
      'endAt': endAt.toUtc().toIso8601String(),
      'grossAmount': grossAmount,
      if (durationHours != null) 'durationHours': durationHours,
      'urgencyLevel': urgencyLevel,
      'requiresVerifiedProfile': requiresVerifiedProfile,
    };
  }
}
