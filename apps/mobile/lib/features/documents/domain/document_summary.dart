class DocumentSummary {
  const DocumentSummary({
    required this.id,
    required this.documentType,
    required this.documentTypeLabel,
    required this.statusLabel,
    required this.fileUrl,
    required this.rejectionReason,
    required this.createdAtLabel,
  });

  final String id;
  final String documentType;
  final String documentTypeLabel;
  final String statusLabel;
  final String fileUrl;
  final String rejectionReason;
  final String createdAtLabel;

  factory DocumentSummary.fromJson(Map<String, dynamic> json) {
    final documentType = json['documentType']?.toString() ?? '';

    return DocumentSummary(
      id: json['id']?.toString() ?? '',
      documentType: documentType,
      documentTypeLabel: documentTypeToLabel(documentType),
      statusLabel: statusToLabel(json['status']?.toString() ?? ''),
      fileUrl: json['fileUrl']?.toString() ?? '',
      rejectionReason: json['rejectionReason']?.toString() ?? '',
      createdAtLabel: _createdAtLabel(json['createdAt']?.toString() ?? ''),
    );
  }

  static String documentTypeToLabel(String type) {
    switch (type.toUpperCase()) {
      case 'PROFILE_PHOTO':
        return 'Foto de perfil';
      case 'CRMV_PROOF':
        return 'Comprovante CRMV';
      case 'ENROLLMENT_STATEMENT':
        return 'Declaracao de matricula';
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

  static String statusToLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pendente';
      case 'IN_REVIEW':
        return 'Em analise';
      case 'APPROVED':
        return 'Aprovado';
      case 'REJECTED':
        return 'Reprovado';
      case 'EXPIRED':
        return 'Expirado';
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

    return '$day/$month/$year as $hour:$minute';
  }
}
