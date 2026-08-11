import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/question_review/domain/question_review_models.dart';

abstract interface class QuestionReviewRepository {
  Future<QuestionReviewSession> fetchDue({int limit = 10});
  Future<QuestionReviewCheck> check({
    required QuestionReviewItem item,
    required String answer,
  });
  Future<QuestionReviewGrade> grade({
    required QuestionReviewItem item,
    required int rating,
    required String operationId,
    required int expectedReps,
    required String answer,
  });
}

class ApiQuestionReviewRepository implements QuestionReviewRepository {
  const ApiQuestionReviewRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<QuestionReviewSession> fetchDue({int limit = 10}) async {
    if (limit < 1 || limit > 10) throw ArgumentError.value(limit, 'limit');
    return QuestionReviewSession.fromJson(
      await _apiClient.get('/reviews/questions/due?limit=$limit'),
    );
  }

  @override
  Future<QuestionReviewCheck> check({
    required QuestionReviewItem item,
    required String answer,
  }) async =>
      QuestionReviewCheck.fromJson(await _apiClient.postJson(
        '/reviews/${item.id}/check',
        body: {'answer': answer},
      ));

  @override
  Future<QuestionReviewGrade> grade({
    required QuestionReviewItem item,
    required int rating,
    required String operationId,
    required int expectedReps,
    required String answer,
  }) async {
    if (rating < 1 || rating > 4) {
      throw const ApiException(code: 'invalid_rating', message: 'Điểm ôn tập không hợp lệ');
    }
    return QuestionReviewGrade.fromJson(await _apiClient.postJson(
      '/reviews/${item.id}/grade',
      body: {
        'rating': rating,
        'operationId': operationId,
        'expectedReps': expectedReps,
        'answer': answer,
      },
    ));
  }
}
