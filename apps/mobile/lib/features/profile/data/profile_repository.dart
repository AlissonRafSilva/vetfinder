import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class ProfileRepository {
  ProfileRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchProfessionalProfile({
    required String userId,
  }) {
    return _apiClient.getJson('/professionals/$userId');
  }

  Future<Map<String, dynamic>> fetchMyInstitutionProfile({
    required String accessToken,
  }) {
    return _apiClient.getJsonWithToken(
      '/institutions/me',
      accessToken: accessToken,
    );
  }

  Future<String> createVeterinarianProfile({
    required String accessToken,
    required String crmvNumber,
    required String crmvState,
    required String baseShiftRate,
    required String yearsExperience,
    required bool emergencyCare,
    required bool canTravel,
    required String maxDistanceKm,
    required String latitude,
    required String longitude,
  }) async {
    final response = await _apiClient.postJson(
      '/professionals/veterinarians',
      accessToken: accessToken,
      body: {
        'crmvNumber': crmvNumber.trim(),
        'crmvState': crmvState.trim().toUpperCase(),
        if (baseShiftRate.trim().isNotEmpty)
          'baseShiftRate': num.tryParse(baseShiftRate.trim()),
        if (yearsExperience.trim().isNotEmpty)
          'yearsExperience': int.tryParse(yearsExperience.trim()),
        'emergencyCare': emergencyCare,
        'canTravel': canTravel,
        if (maxDistanceKm.trim().isNotEmpty)
          'maxDistanceKm': int.tryParse(maxDistanceKm.trim()),
        if (latitude.trim().isNotEmpty) 'lat': num.tryParse(latitude.trim()),
        if (longitude.trim().isNotEmpty) 'lng': num.tryParse(longitude.trim()),
      },
    );

    return response['message']?.toString() ??
        'Perfil veterinario criado com sucesso.';
  }

  Future<String> createInternProfile({
    required String accessToken,
    required String universityName,
    required String coursePeriod,
    required String expectedGraduationDate,
    required String latitude,
    required String longitude,
  }) async {
    final response = await _apiClient.postJson(
      '/professionals/interns',
      accessToken: accessToken,
      body: {
        'universityName': universityName.trim(),
        if (coursePeriod.trim().isNotEmpty) 'coursePeriod': coursePeriod.trim(),
        if (expectedGraduationDate.trim().isNotEmpty)
          'expectedGraduationDate': expectedGraduationDate.trim(),
        if (latitude.trim().isNotEmpty) 'lat': num.tryParse(latitude.trim()),
        if (longitude.trim().isNotEmpty) 'lng': num.tryParse(longitude.trim()),
      },
    );

    return response['message']?.toString() ??
        'Perfil de estagiario criado com sucesso.';
  }

  Future<String> createInstitutionProfile({
    required String accessToken,
    required String institutionType,
    required String legalName,
    required String tradeName,
    required String cnpj,
    required String stateRegistration,
    required String description,
    required String contactName,
    required String contactPhone,
    required String latitude,
    required String longitude,
  }) async {
    final response = await _apiClient.postJson(
      '/institutions',
      accessToken: accessToken,
      body: {
        'institutionType': institutionType,
        'legalName': legalName.trim(),
        'tradeName': tradeName.trim(),
        'cnpj': cnpj.trim(),
        if (stateRegistration.trim().isNotEmpty)
          'stateRegistration': stateRegistration.trim(),
        if (description.trim().isNotEmpty) 'description': description.trim(),
        if (contactName.trim().isNotEmpty) 'contactName': contactName.trim(),
        if (contactPhone.trim().isNotEmpty) 'contactPhone': contactPhone.trim(),
        if (latitude.trim().isNotEmpty) 'lat': num.tryParse(latitude.trim()),
        if (longitude.trim().isNotEmpty) 'lng': num.tryParse(longitude.trim()),
      },
    );

    return response['message']?.toString() ?? 'Instituicao criada com sucesso.';
  }
}
