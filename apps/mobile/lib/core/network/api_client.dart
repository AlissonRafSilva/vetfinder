import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  static const _requestTimeout = Duration(seconds: 12);

  final String baseUrl;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> getJson(String path) async {
    final decoded = await getDynamic(path);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada da API.');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> getJsonWithToken(
    String path, {
    String? accessToken,
  }) async {
    final decoded = await getDynamic(path, accessToken: accessToken);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada da API.');
    }

    return decoded;
  }

  Future<dynamic> getDynamic(
    String path, {
    String? accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response response;
    try {
      response = await _httpClient
          .get(
            uri,
            headers: _buildHeaders(accessToken: accessToken),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        'Tempo esgotado ao conectar com a API. Verifique se o celular está na mesma rede do PC.',
      );
    } catch (_) {
      throw const ApiException(
        'Não foi possível conectar com a API. Verifique o IP do PC, o Wi-Fi e se o backend está ligado.',
      );
    }

    _throwIfRequestFailed(response);

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    String? accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: _buildHeaders(accessToken: accessToken),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        'Tempo esgotado ao conectar com a API. Verifique se o celular está na mesma rede do PC.',
      );
    } catch (_) {
      throw const ApiException(
        'Não foi possível conectar com a API. Verifique o IP do PC, o Wi-Fi e se o backend está ligado.',
      );
    }

    _throwIfRequestFailed(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada da API.');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    required Map<String, dynamic> body,
    String? accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response response;
    try {
      response = await _httpClient
          .put(
            uri,
            headers: _buildHeaders(accessToken: accessToken),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        'Tempo esgotado ao conectar com a API. Verifique se o celular está na mesma rede do PC.',
      );
    } catch (_) {
      throw const ApiException(
        'Não foi possível conectar com a API. Verifique o IP do PC, o Wi-Fi e se o backend está ligado.',
      );
    }

    _throwIfRequestFailed(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada da API.');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, dynamic> body,
    String? accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response response;
    try {
      response = await _httpClient
          .patch(
            uri,
            headers: _buildHeaders(accessToken: accessToken),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        'Tempo esgotado ao conectar com a API. Verifique se o celular está na mesma rede do PC.',
      );
    } catch (_) {
      throw const ApiException(
        'Não foi possível conectar com a API. Verifique o IP do PC, o Wi-Fi e se o backend está ligado.',
      );
    }

    _throwIfRequestFailed(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada da API.');
    }

    return decoded;
  }

  Map<String, String> _buildHeaders({String? accessToken}) {
    return {
      'Content-Type': 'application/json',
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };
  }

  void _throwIfRequestFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
        'Falha ao carregar dados (${response.statusCode}).',
      );
    }

    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'];
      if (message is String && message.isNotEmpty) {
        throw ApiException(message);
      }

      if (message is List && message.isNotEmpty) {
        throw ApiException(message.map((item) => item.toString()).join('\n'));
      }
    }

    throw ApiException(
      'Falha ao carregar dados (${response.statusCode}).',
    );
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
