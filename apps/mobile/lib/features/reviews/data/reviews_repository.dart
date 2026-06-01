import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/review_summary.dart';

class ReviewsRepository {
  ReviewsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<ReviewSummary> createReview({
    required String accessToken,
    required String engagementId,
    required int rating,
    String? comment,
  }) async {
    final response = await _apiClient.postJson(
      '/reviews',
      accessToken: accessToken,
      body: {
        'engagementId': engagementId,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
    );

    final review = response['review'];
    if (review is! Map<String, dynamic>) {
      throw const ApiException('Avaliação retornada pela API é inválida.');
    }

    return ReviewSummary.fromJson(review);
  }

  Future<List<ReviewSummary>> fetchByEngagement({
    required String accessToken,
    required String engagementId,
  }) async {
    final response = await _apiClient.getDynamic(
      '/reviews/engagement/$engagementId',
      accessToken: accessToken,
    );

    if (response is! List) {
      throw const ApiException('Resposta inesperada da API.');
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(ReviewSummary.fromJson)
        .toList();
  }
}
