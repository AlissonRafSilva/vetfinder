import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/create_institution_opportunity_input.dart';
import '../domain/opportunity_detail.dart';
import '../domain/institution_opportunity_option.dart';
import '../domain/opportunity_summary.dart';

class OpportunitiesRepository {
  OpportunitiesRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<List<OpportunitySummary>> fetchOpenOpportunities() async {
    final response = await _apiClient.getJson('/opportunities');
    final items = response['items'];

    if (items is! List) {
      throw const ApiException('Lista de oportunidades invalida.');
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map(OpportunitySummary.fromJson)
        .toList();
  }

  Future<OpportunityDetail> fetchOpportunityDetail(String opportunityId) async {
    final response = await _apiClient.getJson('/opportunities/$opportunityId');
    return OpportunityDetail.fromJson(response);
  }

  Future<List<InstitutionOpportunityOption>> fetchMyInstitutionOpportunities({
    required String accessToken,
  }) async {
    final response = await _apiClient.getDynamic(
      '/opportunities/me',
      accessToken: accessToken,
    );

    if (response is! List) {
      throw const ApiException('Lista de vagas da instituicao invalida.');
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(InstitutionOpportunityOption.fromJson)
        .toList();
  }

  Future<String> applyToOpportunity({
    required String opportunityId,
    required String accessToken,
    String? message,
  }) async {
    final response = await _apiClient.postJson(
      '/applications/opportunities/$opportunityId/apply',
      accessToken: accessToken,
      body: {
        if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
      },
    );

    return response['message']?.toString() ?? 'Candidatura realizada com sucesso.';
  }

  Future<String> createInstitutionOpportunity({
    required String accessToken,
    required CreateInstitutionOpportunityInput input,
  }) async {
    final response = await _apiClient.postJson(
      '/opportunities',
      accessToken: accessToken,
      body: input.toJson(),
    );

    return response['message']?.toString() ?? 'Oportunidade criada com sucesso.';
  }

  Future<String> updateOpportunityStatus({
    required String accessToken,
    required String opportunityId,
    required String status,
  }) async {
    final response = await _apiClient.patchJson(
      '/opportunities/$opportunityId/status',
      accessToken: accessToken,
      body: {
        'status': status,
      },
    );

    return response['message']?.toString() ??
        'Status da oportunidade atualizado com sucesso.';
  }

  Future<String> updateInstitutionOpportunity({
    required String accessToken,
    required String opportunityId,
    required CreateInstitutionOpportunityInput input,
  }) async {
    final response = await _apiClient.patchJson(
      '/opportunities/$opportunityId',
      accessToken: accessToken,
      body: input.toJson(),
    );

    return response['message']?.toString() ?? 'Oportunidade atualizada com sucesso.';
  }
}
