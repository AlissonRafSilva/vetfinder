import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/application_summary.dart';
import '../domain/invite_summary.dart';
import '../domain/opportunity_application_summary.dart';
import '../domain/opportunity_invite_summary.dart';

class ApplicationsRepository {
  ApplicationsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<List<ApplicationSummary>> fetchMyApplications({
    required String accessToken,
  }) async {
    final response = await _apiClient.getDynamic(
      '/applications/me',
      accessToken: accessToken,
    );

    if (response is! List) {
      throw const ApiException('Lista de candidaturas invalida.');
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(ApplicationSummary.fromJson)
        .toList();
  }

  Future<List<InviteSummary>> fetchMyInvites({
    required String accessToken,
  }) async {
    final response = await _apiClient.getDynamic(
      '/applications/invites/me',
      accessToken: accessToken,
    );

    if (response is! List) {
      throw const ApiException('Lista de convites invalida.');
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(InviteSummary.fromJson)
        .toList();
  }

  Future<String> inviteProfessional({
    required String accessToken,
    required String opportunityId,
    required String professionalUserId,
    String? message,
  }) async {
    final response = await _apiClient.postJson(
      '/applications/opportunities/$opportunityId/invite',
      accessToken: accessToken,
      body: {
        'professionalUserId': professionalUserId,
        if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
      },
    );

    return response['message']?.toString() ?? 'Convite enviado com sucesso.';
  }

  Future<String> respondInvite({
    required String accessToken,
    required String inviteId,
    required bool accept,
  }) async {
    final response = await _apiClient.postJson(
      '/applications/invites/$inviteId/respond',
      accessToken: accessToken,
      body: {
        'status': accept ? 'ACCEPTED' : 'DECLINED',
      },
    );

    return response['message']?.toString() ??
        'Resposta do convite registrada com sucesso.';
  }

  Future<List<OpportunityInviteSummary>> fetchInvitesByOpportunity({
    required String accessToken,
    required String opportunityId,
  }) async {
    final response = await _apiClient.getDynamic(
      '/applications/opportunities/$opportunityId/invites',
      accessToken: accessToken,
    );

    if (response is! List) {
      throw const ApiException('Lista de convites da vaga invalida.');
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(OpportunityInviteSummary.fromJson)
        .toList();
  }

  Future<List<OpportunityApplicationSummary>> fetchApplicationsByOpportunity({
    required String accessToken,
    required String opportunityId,
  }) async {
    final response = await _apiClient.getDynamic(
      '/applications/opportunities/$opportunityId',
      accessToken: accessToken,
    );

    if (response is! List) {
      throw const ApiException('Lista de candidaturas da vaga invalida.');
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(OpportunityApplicationSummary.fromJson)
        .toList();
  }

  Future<String> respondApplication({
    required String accessToken,
    required String applicationId,
    required bool accept,
  }) async {
    final response = await _apiClient.postJson(
      '/applications/$applicationId/respond',
      accessToken: accessToken,
      body: {
        'status': accept ? 'ACCEPTED' : 'REJECTED',
      },
    );

    return response['message']?.toString() ??
        'Resposta da candidatura registrada com sucesso.';
  }
}
