import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/notification_summary.dart';

class NotificationsRepository {
  NotificationsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<List<NotificationSummary>> fetchMine({
    required String accessToken,
  }) async {
    final response = await _apiClient.getDynamic(
      '/notifications',
      accessToken: accessToken,
    );

    if (response is! List) {
      throw const ApiException('Lista de notificacoes invalida.');
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(NotificationSummary.fromJson)
        .toList();
  }

  Future<void> markAsRead({
    required String accessToken,
    required String notificationId,
  }) async {
    await _apiClient.patchJson(
      '/notifications/$notificationId/read',
      accessToken: accessToken,
      body: const {},
    );
  }

  Future<void> markAllAsRead({
    required String accessToken,
  }) async {
    await _apiClient.patchJson(
      '/notifications/read-all',
      accessToken: accessToken,
      body: const {},
    );
  }
}
