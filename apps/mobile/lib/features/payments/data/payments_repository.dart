import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/payment_summary.dart';

class PaymentsRepository {
  PaymentsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<PaymentSummary> createCheckoutPayment({
    required String accessToken,
    required String engagementId,
  }) async {
    final response = await _apiClient.postJson(
      '/payments',
      accessToken: accessToken,
      body: {
        'engagementId': engagementId,
        'provider': 'sandbox-split',
      },
    );

    final payment = response['payment'];
    if (payment is! Map<String, dynamic>) {
      throw const ApiException('Pagamento retornado pela API e invalido.');
    }

    return PaymentSummary.fromJson(payment);
  }

  Future<PaymentSummary> confirmSandboxPayment({
    required String accessToken,
    required String paymentId,
  }) async {
    final response = await _apiClient.patchJson(
      '/payments/$paymentId/confirm-sandbox',
      accessToken: accessToken,
      body: const {},
    );

    final payment = response['payment'];
    if (payment is! Map<String, dynamic>) {
      throw const ApiException('Pagamento retornado pela API e invalido.');
    }

    return PaymentSummary.fromJson(payment);
  }

  Future<PaymentSummary?> fetchPaymentByEngagement({
    required String accessToken,
    required String engagementId,
  }) async {
    try {
      final response = await _apiClient.getJsonWithToken(
        '/payments/engagement/$engagementId',
        accessToken: accessToken,
      );

      return PaymentSummary.fromJson(response);
    } on ApiException catch (error) {
      if (error.message.contains('Pagamento nao encontrado')) {
        return null;
      }

      rethrow;
    }
  }
}
