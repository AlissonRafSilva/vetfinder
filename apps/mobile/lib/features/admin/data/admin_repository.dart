import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/admin_document_summary.dart';

class AdminRepository {
  AdminRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<List<AdminDocumentSummary>> fetchPendingDocuments({
    required String accessToken,
  }) async {
    final response = await _apiClient.getDynamic(
      '/admin/documents?status=PENDING',
      accessToken: accessToken,
    );

    if (response is! List) {
      throw const ApiException('Lista de documentos invalida.');
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(AdminDocumentSummary.fromJson)
        .toList();
  }

  Future<String> reviewDocument({
    required String accessToken,
    required String documentId,
    required String status,
    String? rejectionReason,
  }) async {
    final response = await _apiClient.patchJson(
      '/admin/documents/$documentId/review',
      accessToken: accessToken,
      body: {
        'status': status,
        if (rejectionReason != null && rejectionReason.trim().isNotEmpty)
          'rejectionReason': rejectionReason.trim(),
      },
    );

    return response['message']?.toString() ??
        'Revisao administrativa registrada.';
  }
}
