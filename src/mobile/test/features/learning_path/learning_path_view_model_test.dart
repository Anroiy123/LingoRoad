import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/learning_path/data/learning_path_repository.dart';
import 'package:lingoroad_mobile/features/learning_path/domain/learning_path_models.dart';
import 'package:lingoroad_mobile/features/learning_path/presentation/learning_path_view_model.dart';

const sampleStep = LearningPathStep(
  code: 'vocab.travel',
  name: 'Travel vocabulary',
  nameVi: 'Từ vựng du lịch',
  cefr: 'A2',
  mastery: 0.4,
  reason: 'below_threshold',
);

class FakeLearningPathRepository implements LearningPathRepository {
  List<LearningPathStep> result = const [sampleStep];
  Object? error;
  Completer<List<LearningPathStep>>? pending;
  int calls = 0;

  @override
  Future<List<LearningPathStep>> fetch({int limit = 10}) async {
    calls++;
    if (error != null) {
      throw error!;
    }
    return pending?.future ?? result;
  }
}

void main() {
  late FakeLearningPathRepository repository;
  late LearningPathViewModel viewModel;

  setUp(() {
    repository = FakeLearningPathRepository();
    viewModel = LearningPathViewModel(repository);
  });

  test('load chuyển loading sang success', () async {
    final pending = Completer<List<LearningPathStep>>();
    repository.pending = pending;

    final load = viewModel.load();
    expect(viewModel.state, LearningPathState.loading);

    pending.complete(const [sampleStep]);
    await load;

    expect(viewModel.state, LearningPathState.success);
    expect(viewModel.steps, const [sampleStep]);
  });

  test('danh sách rỗng tạo empty state', () async {
    repository.result = const [];

    await viewModel.load();

    expect(viewModel.state, LearningPathState.empty);
    expect(viewModel.steps, isEmpty);
  });

  test('lỗi giữ error code và retry thành công', () async {
    repository.error = const ApiException(
      code: 'network_unavailable',
      message: 'offline',
    );

    await viewModel.load();

    expect(viewModel.state, LearningPathState.error);
    expect(viewModel.errorCode, 'network_unavailable');

    repository.error = null;
    await viewModel.retry();

    expect(viewModel.state, LearningPathState.success);
    expect(repository.calls, 2);
  });

  test('chặn request trùng khi đang loading', () async {
    repository.pending = Completer<List<LearningPathStep>>();

    final first = viewModel.load();
    await viewModel.load();

    expect(repository.calls, 1);
    repository.pending!.complete(const [sampleStep]);
    await first;
  });
}
