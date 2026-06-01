import '../../../core/formatters/opportunity_formatter.dart';

class OpportunityInviteSummary {
  const OpportunityInviteSummary({
    required this.id,
    required this.professionalUserId,
    required this.professionalName,
    required this.professionalEmail,
    required this.statusValue,
    required this.statusLabel,
    required this.invitedAtLabel,
  });

  final String id;
  final String professionalUserId;
  final String professionalName;
  final String professionalEmail;
  final String statusValue;
  final String statusLabel;
  final String invitedAtLabel;

  bool get canFinalize => statusValue == 'ACCEPTED';

  factory OpportunityInviteSummary.fromJson(Map<String, dynamic> json) {
    final professional = json['professional'] as Map<String, dynamic>?;
    final profile = professional?['profile'] as Map<String, dynamic>?;

    return OpportunityInviteSummary(
      id: json['id']?.toString() ?? '',
      professionalUserId: professional?['id']?.toString() ?? '',
      professionalName:
          profile?['fullName']?.toString() ??
          professional?['email']?.toString() ??
          'Profissional',
      professionalEmail: professional?['email']?.toString() ?? '',
      statusValue: json['status']?.toString() ?? '',
      statusLabel: _statusLabel(json['status']?.toString() ?? ''),
      invitedAtLabel: _invitedAtLabel(json['invitedAt']?.toString() ?? ''),
    );
  }

  static String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'SENT':
        return 'Convite enviado';
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
      return 'Data indisponivel';
    }

    return 'Enviado em ${OpportunityFormatter.shortDate(parsed)} às ${OpportunityFormatter.hourLabel(parsed)}';
  }
}
