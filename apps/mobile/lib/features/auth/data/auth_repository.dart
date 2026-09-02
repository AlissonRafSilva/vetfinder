import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/app_user_role.dart';
import '../domain/auth_result.dart';

class AuthRepository {
  AuthRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<AuthResult> register({
    required String email,
    required String password,
    required AppUserRole role,
    String? phone,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/register',
      body: {
        'email': email.trim(),
        'password': password,
        'phone': phone?.trim().isEmpty ?? true ? null : phone?.trim(),
        'role': role.apiValue,
      },
    );

    return AuthResult.fromRegisterJson(response);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/login',
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    return AuthResult.fromLoginJson(response);
  }

  Future<String> changePassword({
    required String accessToken,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/change-password',
      accessToken: accessToken,
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    return response['message']?.toString() ?? 'Senha atualizada com sucesso.';
  }

  Future<AuthResult> fetchCurrentUser({
    required String accessToken,
    required AuthResult currentSession,
  }) async {
    final response = await _apiClient.getJsonWithToken(
      '/users/me',
      accessToken: accessToken,
    );

    return AuthResult.fromUserJson(
      response,
      currentSession: currentSession,
    );
  }
}
