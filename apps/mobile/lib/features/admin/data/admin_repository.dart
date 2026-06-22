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

    final documents = response
        .whereType<Map<String, dynamic>>()
        .map(AdminDocumentSummary.fromJson)
        .toList();

    return Future.wait(
      documents.map(
        (document) async {
          final fileUrl = await createDocumentFileAccessUrl(
            accessToken: accessToken,
            documentId: document.id,
          );

          return document.copyWith(fileUrl: fileUrl);
        },
      ),
    );
  }

  Future<String> createDocumentFileAccessUrl({
    required String accessToken,
    required String documentId,
  }) async {
    final response = await _apiClient.postJson(
      '/documents/$documentId/file-access',
      accessToken: accessToken,
      body: const {},
    );

    return response['url']?.toString() ?? '';
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
