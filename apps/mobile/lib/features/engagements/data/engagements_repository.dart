import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/engagement_summary.dart';

class EngagementsRepository {
  EngagementsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<String> createEngagement({
    required String accessToken,
    required String opportunityId,
    required String professionalUserId,
    required String sourceType,
    required String sourceId,
    required num grossAmount,
  }) async {
    final response = await _apiClient.postJson(
      '/engagements',
      accessToken: accessToken,
      body: {
        'opportunityId': opportunityId,
        'professionalUserId': professionalUserId,
        'sourceType': sourceType,
        'sourceId': sourceId,
        'grossAmount': grossAmount,
      },
    );

    return response['message']?.toString() ?? 'Plantão fechado com sucesso.';
  }

  Future<List<EngagementSummary>> fetchMyInstitutionEngagements({
    required String accessToken,
  }) async {
    final response = await _apiClient.getDynamic(
      '/engagements/me',
      accessToken: accessToken,
    );

    if (response is! List) {
      throw const ApiException('Lista de contratações inválida.');
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(EngagementSummary.fromJson)
        .toList();
  }

  Future<List<EngagementSummary>> fetchMyProfessionalEngagements({
    required String accessToken,
  }) async {
    final response = await _apiClient.getDynamic(
      '/engagements/professional/me',
      accessToken: accessToken,
    );

    if (response is! List) {
      throw const ApiException('Lista de plantões fechados inválida.');
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(EngagementSummary.fromJson)
        .toList();
  }
}
