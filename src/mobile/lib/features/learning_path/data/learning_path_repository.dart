import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/learning_path/domain/learning_path_models.dart';

abstract interface class LearningPathRepository {
  Future<List<LearningPathStep>> fetch({int limit = 10});
}

class ApiLearningPathRepository implements LearningPathRepository {
  const ApiLearningPathRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<LearningPathStep>> fetch({int limit = 10}) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Phải nằm trong khoảng 1–100');
    }

    final response = await _apiClient.get('/path?limit=$limit');
    if (response is! List) {
      throw const ApiException(
        code: 'malformed_response',
        message: 'Phản hồi lộ trình học không hợp lệ',
      );
    }

    return response.map(LearningPathStep.fromJson).toList(growable: false);
  }
}
