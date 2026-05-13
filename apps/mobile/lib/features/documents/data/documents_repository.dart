import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/document_summary.dart';

class DocumentsRepository {
  DocumentsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<List<DocumentSummary>> fetchMine({
    required String accessToken,
  }) async {
    final response = await _apiClient.getDynamic(
      '/documents/me',
      accessToken: accessToken,
    );

    if (response is! List) {
      throw const ApiException('Lista de documentos invalida.');
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(DocumentSummary.fromJson)
        .toList();
  }

  Future<String> submitDocument({
    required String accessToken,
    required String ownerType,
    required String documentType,
    required String fileUrl,
  }) async {
    final response = await _apiClient.postJson(
      '/documents',
      accessToken: accessToken,
      body: {
        'ownerType': ownerType,
        'documentType': documentType,
        'fileUrl': fileUrl.trim(),
      },
    );

    return response['message']?.toString() ?? 'Documento enviado com sucesso.';
  }
}
