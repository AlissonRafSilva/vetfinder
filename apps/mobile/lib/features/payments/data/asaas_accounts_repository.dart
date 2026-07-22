import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/asaas_account_summary.dart';

class AsaasAccountsRepository {
  AsaasAccountsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<AsaasAccountSummary?> fetchMine({
    required String accessToken,
  }) async {
    try {
      final response = await _apiClient.getJsonWithToken(
        '/payments/asaas/accounts/me',
        accessToken: accessToken,
      );
      return AsaasAccountSummary.fromJson(response);
    } on ApiException catch (error) {
      if (error.message.contains('Cadastro financeiro não encontrado') ||
          error.message.contains('Cadastro financeiro nao encontrado')) {
        return null;
      }
      rethrow;
    }
  }

  Future<AsaasAccountSummary> create({
    required String accessToken,
    required Map<String, dynamic> data,
  }) async {
    final response = await _apiClient.postJson(
      '/payments/asaas/accounts',
      accessToken: accessToken,
      body: data,
    );
    return AsaasAccountSummary.fromJson(response);
  }
}
