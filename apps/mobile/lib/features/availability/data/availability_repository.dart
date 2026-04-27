import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/available_professional_summary.dart';
import '../domain/availability_slot_model.dart';

class AvailabilityRepository {
  AvailabilityRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<List<AvailabilitySlotModel>> fetchMyAvailability({
    required String accessToken,
  }) async {
    final response = await _apiClient.getDynamic(
      '/availability/me',
      accessToken: accessToken,
    );

    if (response is! List) {
      throw const ApiException('Lista de disponibilidade invalida.');
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(AvailabilitySlotModel.fromJson)
        .toList();
  }

  Future<List<AvailabilitySlotModel>> saveMyAvailability({
    required String accessToken,
    required List<AvailabilitySlotModel> slots,
  }) async {
    final response = await _apiClient.putJson(
      '/availability/me',
      accessToken: accessToken,
      body: {
        'slots': slots.map((slot) => slot.toJson()).toList(),
      },
    );

    final data = response['slots'];
    if (data is! List) {
      throw const ApiException('Resposta de disponibilidade invalida.');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(AvailabilitySlotModel.fromJson)
        .toList();
  }

  Future<List<AvailableProfessionalSummary>> searchAvailableProfessionals({
    required String accessToken,
    int? weekday,
    String? startTime,
    String? endTime,
  }) async {
    final queryParameters = <String, String>{
      if (weekday != null) 'weekday': weekday.toString(),
      if (startTime != null && startTime.isNotEmpty) 'startTime': startTime,
      if (endTime != null && endTime.isNotEmpty) 'endTime': endTime,
    };

    final path = Uri(
      path: '/availability/professionals',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();

    final response = await _apiClient.getDynamic(
      path,
      accessToken: accessToken,
    );

    if (response is! List) {
      throw const ApiException('Lista de profissionais disponiveis invalida.');
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(AvailableProfessionalSummary.fromJson)
        .toList();
  }
}
