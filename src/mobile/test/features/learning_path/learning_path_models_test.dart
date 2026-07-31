import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/learning_path/domain/learning_path_models.dart';

void main() {
  test('đọc một bước lộ trình hợp lệ', () {
    final step = LearningPathStep.fromJson({
      'code': 'grammar.present-simple',
      'name': 'Present simple',
      'nameVi': 'Thì hiện tại đơn',
      'cefr': 'A2',
      'mastery': 0.35,
      'reason': 'below_threshold',
    });

    expect(step.code, 'grammar.present-simple');
    expect(step.nameVi, 'Thì hiện tại đơn');
    expect(step.cefr, 'A2');
    expect(step.mastery, 0.35);
  });

  test('từ chối CEFR ngoài phạm vi MVP', () {
    expect(
      () => LearningPathStep.fromJson({
        'code': 'advanced',
        'name': 'Advanced',
        'nameVi': 'Nâng cao',
        'cefr': 'C1',
        'mastery': 0,
        'reason': 'not_started',
      }),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'malformed_response',
        ),
      ),
    );
  });

  test('từ chối mastery ngoài khoảng 0–1', () {
    expect(
      () => LearningPathStep.fromJson({
        'code': 'grammar',
        'name': 'Grammar',
        'nameVi': 'Ngữ pháp',
        'cefr': 'B1',
        'mastery': 1.2,
        'reason': 'below_threshold',
      }),
      throwsA(isA<ApiException>()),
    );
  });
}
