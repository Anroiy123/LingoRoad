import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/lesson/domain/lesson_models.dart';

abstract interface class LessonRepository {
  Future<List<TodayLesson>> today();
  Future<LessonAttempt> start(String lessonId, String operationId);
  Future<LessonAttempt> getAttempt(String attemptId);
  Future<ExerciseFeedback> submit({
    required String exerciseId,
    required String answer,
    required String operationId,
  });
  Future<LessonCompletion> complete(String attemptId, String operationId);
}

class ApiLessonRepository implements LessonRepository {
  const ApiLessonRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<TodayLesson>> today() async {
    final response = await _apiClient.get('/path/today');
    if (response is! List) throw _malformed();
    return response.map(TodayLesson.fromJson).toList(growable: false);
  }

  @override
  Future<LessonAttempt> start(String lessonId, String operationId) async =>
      LessonAttempt.fromJson(await _apiClient.postJson(
        '/lessons/$lessonId/attempts',
        body: {'operationId': operationId},
      ));

  @override
  Future<LessonAttempt> getAttempt(String attemptId) async =>
      LessonAttempt.fromJson(
          await _apiClient.get('/lesson-attempts/$attemptId'));

  @override
  Future<ExerciseFeedback> submit({
    required String exerciseId,
    required String answer,
    required String operationId,
  }) async =>
      ExerciseFeedback.fromJson(await _apiClient.postJson(
        '/exercises/$exerciseId/submit',
        body: {'answer': answer, 'operationId': operationId},
      ));

  @override
  Future<LessonCompletion> complete(
          String attemptId, String operationId) async =>
      LessonCompletion.fromJson(await _apiClient.postJson(
        '/lesson-attempts/$attemptId/complete',
        body: {'operationId': operationId},
      ));
}

ApiException _malformed() => const ApiException(
      code: 'malformed_response',
      message: 'Phản hồi bài học không hợp lệ',
    );
