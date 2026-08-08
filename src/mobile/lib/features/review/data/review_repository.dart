import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/review/domain/review_models.dart';

abstract interface class ReviewRepository {
  Future<List<ReviewCard>> fetchDue();
  Future<void> grade(
      {required ReviewCard card,
      required int rating,
      required String operationId});
  Future<void> createCard(String skillCode, String front, String back);
}

class ApiReviewRepository implements ReviewRepository {
  const ApiReviewRepository(this._apiClient);
  final ApiClient _apiClient;
  @override
  Future<List<ReviewCard>> fetchDue() async {
    final response = await _apiClient.get('/reviews/due');
    if (response is! List) {
      throw const ApiException(
          code: 'malformed_response', message: 'Phản hồi ôn tập không hợp lệ');
    }
    return response.map(ReviewCard.fromJson).toList(growable: false);
  }

  @override
  Future<void> grade(
      {required ReviewCard card,
      required int rating,
      required String operationId}) async {
    await _apiClient.postJson('/reviews/${card.id}/grade', body: {
      'rating': rating,
      'operationId': operationId,
      'expectedReps': card.reps
    });
  }

  @override
  Future<void> createCard(String skillCode, String front, String back) async {
    await _apiClient.postJson('/reviews/cards', body: {
      'skillCode': skillCode,
      'front': front,
      'back': back,
    });
  }
}
