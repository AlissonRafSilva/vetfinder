import 'availability_slot_model.dart';

class AvailableProfessionalSummary {
  const AvailableProfessionalSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.roleValue,
    required this.roleLabel,
    required this.cityLabel,
    required this.rateLabel,
    required this.reputationLabel,
    required this.verificationLabel,
    required this.trustLabel,
    required this.trustDescription,
    required this.completenessLabel,
    required this.isVerified,
    required this.specialtyLabel,
    required this.availability,
  });

  final String id;
  final String name;
  final String email;
  final String roleValue;
  final String roleLabel;
  final String cityLabel;
  final String rateLabel;
  final String reputationLabel;
  final String verificationLabel;
  final String trustLabel;
  final String trustDescription;
  final String completenessLabel;
  final bool isVerified;
  final String specialtyLabel;
  final List<AvailabilitySlotModel> availability;

  factory AvailableProfessionalSummary.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    final veterinarianProfile =
        json['veterinarianProfile'] as Map<String, dynamic>?;
    final internProfile = json['internProfile'] as Map<String, dynamic>?;
    final verificationStatus =
        veterinarianProfile?['verificationStatus']?.toString() ??
            internProfile?['verificationStatus']?.toString() ??
            '';
    final completenessScore = _completenessScore(
      profile: profile,
      veterinarianProfile: veterinarianProfile,
      internProfile: internProfile,
      role: json['role']?.toString() ?? '',
    );
    final availability =
        (json['availabilitySlots'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AvailabilitySlotModel.fromJson)
            .toList();

    return AvailableProfessionalSummary(
      id: json['id']?.toString() ?? '',
      name: profile?['fullName']?.toString() ??
          json['email']?.toString() ??
          'Profissional',
      email: json['email']?.toString() ?? '',
      roleValue: json['role']?.toString() ?? '',
      roleLabel: _roleLabel(json['role']?.toString() ?? ''),
      cityLabel: _cityLabel(profile),
      rateLabel: _rateLabel(veterinarianProfile),
      reputationLabel: _reputationLabel(json['reviewReceived']),
      verificationLabel: _verificationLabel(verificationStatus),
      trustLabel: _trustLabel(verificationStatus, completenessScore),
      trustDescription: _trustDescription(verificationStatus, completenessScore),
      completenessLabel: 'Perfil $completenessScore% completo',
      isVerified: verificationStatus.toUpperCase() == 'APPROVED',
      specialtyLabel: _specialtyLabel(json),
      availability: availability,
    );
  }

  static String _roleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'VETERINARIAN':
        return 'Veterinário';
      case 'INTERN':
        return 'Estagiario';
      default:
        return role.isEmpty ? 'Profissional' : role;
    }
  }

  static String _cityLabel(Map<String, dynamic>? profile) {
    final city = profile?['city']?.toString() ?? '';
    final state = profile?['state']?.toString() ?? '';

    if (city.isEmpty && state.isEmpty) {
      return 'Região não informada';
    }

    return [city, state].where((part) => part.isNotEmpty).join(' - ');
  }

  static String _rateLabel(Map<String, dynamic>? veterinarianProfile) {
    final rate = veterinarianProfile?['baseShiftRate'];
    if (rate == null) {
      return 'Valor a combinar';
    }

    return 'Base R\$ ${rate.toString()}';
  }

  static String _reputationLabel(dynamic reviews) {
    if (reviews is! List || reviews.isEmpty) {
      return 'Sem avaliacoes ainda';
    }

    final ratings = reviews
        .whereType<Map<String, dynamic>>()
        .map((review) => int.tryParse(review['rating']?.toString() ?? '') ?? 0)
        .where((rating) => rating > 0)
        .toList();

    if (ratings.isEmpty) {
      return 'Sem avaliacoes ainda';
    }

    final average = ratings.reduce((sum, rating) => sum + rating) / ratings.length;
    final countLabel = ratings.length == 1 ? '1 avaliação' : '${ratings.length} avaliações';

    return '★ ${average.toStringAsFixed(1)} ($countLabel)';
  }

  static String _verificationLabel(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return 'Perfil verificado';
      case 'PENDING':
        return 'Documentos pendentes';
      default:
        return status.isEmpty ? 'Perfil sem status' : status;
    }
  }

  static String _trustLabel(String status, int completenessScore) {
    if (status.toUpperCase() == 'APPROVED') {
      return 'Mais confiavel';
    }

    if (completenessScore >= 70) {
      return 'Perfil em evolucao';
    }

    return 'Perfil basico';
  }

  static String _trustDescription(String status, int completenessScore) {
    if (status.toUpperCase() == 'APPROVED') {
      return 'Documentos aprovados e perfil priorizado na busca.';
    }

    if (completenessScore >= 70) {
      return 'Tem boa parte do cadastro preenchido, mas ainda sem validação completa.';
    }

    return 'Pode ser convidado, mas tende a receber menos destaque até completar o perfil.';
  }

  static int _completenessScore({
    required Map<String, dynamic>? profile,
    required Map<String, dynamic>? veterinarianProfile,
    required Map<String, dynamic>? internProfile,
    required String role,
  }) {
    var completed = 0;
    const total = 5;

    if ((profile?['fullName']?.toString() ?? '').isNotEmpty) completed++;
    if ((profile?['city']?.toString() ?? '').isNotEmpty ||
        (profile?['state']?.toString() ?? '').isNotEmpty) {
      completed++;
    }
    if ((profile?['bio']?.toString() ?? '').isNotEmpty) completed++;

    if (role.toUpperCase() == 'INTERN') {
      if ((internProfile?['universityName']?.toString() ?? '').isNotEmpty) {
        completed++;
      }
      if ((internProfile?['coursePeriod']?.toString() ?? '').isNotEmpty) {
        completed++;
      }
    } else {
      if ((veterinarianProfile?['crmvNumber']?.toString() ?? '').isNotEmpty) {
        completed++;
      }
      if (veterinarianProfile?['baseShiftRate'] != null) completed++;
    }

    return ((completed / total) * 100).round().clamp(0, 100);
  }

  static String _specialtyLabel(Map<String, dynamic> json) {
    final specialties = (json['specialties'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => item['specialty'])
        .whereType<Map<String, dynamic>>()
        .map((specialty) => specialty['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    if (specialties.isNotEmpty) {
      return specialties.join(', ');
    }

    final veterinarianProfile =
        json['veterinarianProfile'] as Map<String, dynamic>?;
    if (veterinarianProfile != null &&
        veterinarianProfile['emergencyCare'] == true) {
      return 'Emergencia';
    }

    final role = json['role']?.toString() ?? '';
    if (role.toUpperCase() == 'INTERN') {
      return 'Interesse em estágio';
    }

    return 'Clínica geral';
  }
}
