import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vetfinder_mobile/core/network/api_client.dart';
import 'package:vetfinder_mobile/features/payments/data/payments_repository.dart';

void main() {
  test('checkout sends exactly the total explicitly approved by the clinic',
      () async {
    final requests = <http.Request>[];
    final repository = PaymentsRepository(
      apiClient: ApiClient(
        baseUrl: 'https://example.test/v1',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/quote')) {
            return http.Response(
                jsonEncode({
                  'serviceAmount': 250,
                  'subtotalAmount': 257.5,
                  'chargeAmount': 259.49,
                  'gatewayFeeAmount': 1.99,
                  'platformFeeAmount': 7.5,
                  'professionalAmount': 250,
                  'environment': 'sandbox',
                  'gatewayFeePayer': 'INSTITUTION',
                  'platformFeePayer': 'INSTITUTION',
                }),
                200);
          }
          return http.Response(
              jsonEncode({
                'payment': {
                  'id': 'test-payment',
                  'status': 'PENDING',
                  'provider': 'asaas'
                },
              }),
              201);
        }),
      ),
    );
    final quote = await repository.quotePayment(
      accessToken: 'test-token',
      engagementId: 'test-engagement',
    );
    expect(requests, hasLength(1));
    await repository.createCheckoutPayment(
      accessToken: 'test-token',
      engagementId: 'test-engagement',
      expectedChargeAmount: quote.chargeAmount,
    );
    expect(requests.last.headers['authorization'], 'Bearer test-token');
    expect(jsonDecode(requests.last.body), {
      'engagementId': 'test-engagement',
      'expectedChargeAmount': 259.49,
    });
  });
}
