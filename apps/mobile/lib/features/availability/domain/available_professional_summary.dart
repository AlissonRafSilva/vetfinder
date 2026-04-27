import 'availability_slot_model.dart';

class AvailableProfessionalSummary {
  const AvailableProfessionalSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.roleLabel,
    required this.cityLabel,
    required this.rateLabel,
    required this.verificationLabel,
    required this.specialtyLabel,
    required this.availability,
  });

  final String id;
  final String name;
  final String email;
  final String roleLabel;
  final String cityLabel;
  final String rateLabel;
  final String verificationLabel;
  final String specialtyLabel;
  final List<AvailabilitySlotModel> availability;

  factory AvailableProfessionalSummary.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    final veterinarianProfile = json['veterinarianProfile'] as Map<String, dynamic>?;
    final internProfile = json['internProfile'] as Map<String, dynamic>?;
    final availability = (json['availabilitySlots'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AvailabilitySlotModel.fromJson)
        .toList();

    return AvailableProfessionalSummary(
      id: json['id']?.toString() ?? '',
      name: profile?['fullName']?.toString() ?? json['email']?.toString() ?? 'Profissional',
      email: json['email']?.toString() ?? '',
      roleLabel: _roleLabel(json['role']?.toString() ?? ''),
      cityLabel: _cityLabel(profile),
      rateLabel: _rateLabel(veterinarianProfile),
      verificationLabel: _verificationLabel(
        veterinarianProfile?['verificationStatus']?.toString() ??
            internProfile?['verificationStatus']?.toString() ??
            '',
      ),
      specialtyLabel: _specialtyLabel(json),
      availability: availability,
    );
  }

  static String _roleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'VETERINARIAN':
        return 'Veterinario';
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
      return 'Regiao nao informada';
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

  static String _verificationLabel(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return 'Validado';
      case 'PENDING':
        return 'Pendente';
      default:
        return status.isEmpty ? 'Perfil sem status' : status;
    }
  }

  static String _specialtyLabel(Map<String, dynamic> json) {
    final veterinarianProfile = json['veterinarianProfile'] as Map<String, dynamic>?;
    if (veterinarianProfile != null && veterinarianProfile['emergencyCare'] == true) {
      return 'Emergencia';
    }

    final role = json['role']?.toString() ?? '';
    if (role.toUpperCase() == 'INTERN') {
      return 'Interesse em estagio';
    }

    return 'Clinica geral';
  }
}
