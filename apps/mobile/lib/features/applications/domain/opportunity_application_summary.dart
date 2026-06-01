class OpportunityApplicationSummary {
  const OpportunityApplicationSummary({
    required this.id,
    required this.professionalUserId,
    required this.professionalName,
    required this.professionalEmail,
    required this.professionalRoleLabel,
    required this.statusValue,
    required this.statusLabel,
    required this.appliedAtLabel,
    this.message,
  });

  final String id;
  final String professionalUserId;
  final String professionalName;
  final String professionalEmail;
  final String professionalRoleLabel;
  final String statusValue;
  final String statusLabel;
  final String appliedAtLabel;
  final String? message;

  bool get canRespond => statusValue == 'APPLIED';
  bool get canFinalize => statusValue == 'ACCEPTED';

  factory OpportunityApplicationSummary.fromJson(Map<String, dynamic> json) {
    final professional = json['professional'] as Map<String, dynamic>?;
    final profile = professional?['profile'] as Map<String, dynamic>?;
    final roleValue = professional?['role']?.toString() ?? '';

    return OpportunityApplicationSummary(
      id: json['id']?.toString() ?? '',
      professionalUserId: professional?['id']?.toString() ?? '',
      professionalName:
          profile?['fullName']?.toString() ??
          professional?['email']?.toString() ??
          'Profissional',
      professionalEmail: professional?['email']?.toString() ?? '',
      professionalRoleLabel: _roleLabel(roleValue),
      statusValue: json['status']?.toString() ?? '',
      statusLabel: _statusLabel(json['status']?.toString() ?? ''),
      appliedAtLabel: _appliedAtLabel(json['appliedAt']?.toString() ?? ''),
      message: json['message']?.toString(),
    );
  }

  static String _roleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'VETERINARIAN':
        return 'Veterinário volante';
      case 'INTERN':
        return 'Estagiario';
      default:
        return 'Profissional';
    }
  }

  static String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'APPLIED':
        return 'Candidatura enviada';
      case 'ACCEPTED':
        return 'Candidatura aceita';
      case 'REJECTED':
        return 'Candidatura recusada';
      default:
        return status.isEmpty ? 'Em analise' : status;
    }
  }

  static String _appliedAtLabel(String appliedAt) {
    final parsed = DateTime.tryParse(appliedAt)?.toLocal();
    if (parsed == null) {
      return 'Data de candidatura indisponível';
    }

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return 'Enviada em $day/$month/$year às $hour:$minute';
  }
}
