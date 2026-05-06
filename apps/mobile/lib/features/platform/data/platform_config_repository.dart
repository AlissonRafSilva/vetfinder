import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/platform_config.dart';

class PlatformConfigRepository {
  PlatformConfigRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<PlatformConfig> fetchConfig() async {
    final response = await _apiClient.getJson('/platform/config');
    return PlatformConfig.fromJson(response);
  }
}
