class AdminDocumentSummary {
  const AdminDocumentSummary({
    required this.id,
    required this.ownerLabel,
    required this.ownerSubtitle,
    required this.documentTypeLabel,
    required this.statusLabel,
    required this.fileUrl,
    required this.createdAtLabel,
  });

  final String id;
  final String ownerLabel;
  final String ownerSubtitle;
  final String documentTypeLabel;
  final String statusLabel;
  final String fileUrl;
  final String createdAtLabel;

  bool get isImage {
    final lowerUrl = fileUrl.toLowerCase();
    return lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png');
  }

  factory AdminDocumentSummary.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final institution = json['institution'] as Map<String, dynamic>?;
    final profile = user?['profile'] as Map<String, dynamic>?;

    final ownerLabel = institution?['tradeName']?.toString() ??
        profile?['fullName']?.toString() ??
        user?['email']?.toString() ??
        'Solicitante';
    final ownerSubtitle = institution?['institutionType']?.toString() ??
        user?['role']?.toString() ??
        'Perfil';

    return AdminDocumentSummary(
      id: json['id']?.toString() ?? '',
      ownerLabel: ownerLabel,
      ownerSubtitle: ownerSubtitle,
      documentTypeLabel:
          _documentTypeLabel(json['documentType']?.toString() ?? ''),
      statusLabel: _statusLabel(json['status']?.toString() ?? ''),
      fileUrl: json['fileUrl']?.toString() ?? '',
      createdAtLabel: _createdAtLabel(json['createdAt']?.toString() ?? ''),
    );
  }

  static String _documentTypeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'PROFILE_PHOTO':
        return 'Foto de perfil';
      case 'CRMV_PROOF':
        return 'Comprovante CRMV';
      case 'ENROLLMENT_STATEMENT':
        return 'Declaração de matrícula';
      case 'CNPJ_PROOF':
        return 'Comprovante CNPJ';
      case 'IDENTITY_DOCUMENT':
        return 'Documento de identidade';
      case 'SELFIE':
        return 'Selfie';
      default:
        return type.isEmpty ? 'Documento' : type;
    }
  }

  static String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pendente';
      case 'IN_REVIEW':
        return 'Em analise';
      case 'APPROVED':
        return 'Aprovado';
      case 'REJECTED':
        return 'Reprovado';
      default:
        return status.isEmpty ? 'Sem status' : status;
    }
  }

  static String _createdAtLabel(String createdAt) {
    final parsed = DateTime.tryParse(createdAt)?.toLocal();
    if (parsed == null) {
      return 'Sem data';
    }

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');

    return '$day/$month/$year às $hour:$minute';
  }
}
