import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/payment_summary.dart';
import '../domain/payment_quote.dart';

class PaymentsRepository {
  PaymentsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<PaymentQuote> quotePayment({
    required String accessToken,
    required String engagementId,
  }) async {
    final response = await _apiClient.postJson(
      '/payments/quote',
      accessToken: accessToken,
      body: {'engagementId': engagementId},
    );
    try {
      return PaymentQuote.fromJson(response);
    } on FormatException {
      throw const ApiException(
          'Nao foi possivel validar a tarifa. Tente novamente.');
    }
  }

  Future<PaymentSummary> createCheckoutPayment({
    required String accessToken,
    required String engagementId,
    required double expectedChargeAmount,
  }) async {
    final response = await _apiClient.postJson(
      '/payments',
      accessToken: accessToken,
      body: {
        'engagementId': engagementId,
        'expectedChargeAmount': expectedChargeAmount,
      },
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
      if (error.message.contains('Pagamento nao encontrado') ||
          error.message.contains('Pagamento não encontrado')) {
        return null;
      }

      rethrow;
    }
  }
}
