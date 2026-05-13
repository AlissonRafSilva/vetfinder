import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

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

  Future<String> uploadDocument({
    required String accessToken,
    required String ownerType,
    required String documentType,
    required PlatformFile file,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/documents/upload');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..fields['ownerType'] = ownerType
      ..fields['documentType'] = documentType;

    if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
        ),
      );
    } else if (file.path != null && file.path!.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
        ),
      );
    } else {
      throw const ApiException('Nao foi possivel ler o arquivo selecionado.');
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessageFromResponse(response));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada da API.');
    }

    return decoded['message']?.toString() ?? 'Documento enviado com sucesso.';
  }

  String _errorMessageFromResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }

        if (message is List && message.isNotEmpty) {
          return message.map((item) => item.toString()).join('\n');
        }
      }
    } catch (_) {
      return 'Falha ao enviar documento (${response.statusCode}).';
    }

    return 'Falha ao enviar documento (${response.statusCode}).';
  }
}
