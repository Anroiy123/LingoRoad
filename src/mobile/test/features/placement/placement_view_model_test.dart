import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/placement/data/placement_repository.dart';
import 'package:lingoroad_mobile/features/placement/domain/placement_models.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_view_model.dart';

const firstItem = PlacementItem(
  id: 'item-1',
  type: 'multiple_choice',
  stem: 'First question',
  options: ['A', 'B'],
);

const secondItem = PlacementItem(
  id: 'item-2',
  type: 'multiple_choice',
  stem: 'Second question',
  options: ['True', 'False'],
);

class FakePlacementRepository implements PlacementRepository {
  Object? error;
  PlacementStep step = const PlacementStep(
    done: false,
    item: secondItem,
  );
  PlacementResult finalResult = const PlacementResult(
    theta: 0.7,
    se: 0.3,
    cefr: 'B1',
    itemsAnswered: 2,
    status: 'completed',
  );
  Completer<PlacementStart>? pendingStart;
  int startCalls = 0;
  String? receivedAnswer;

  @override
  Future<PlacementStart> start() async {
    startCalls++;
    if (error != null) {
      throw error!;
    }
    return pendingStart?.future ??
        const PlacementStart(sessionId: 'session-1', item: firstItem);
  }

  @override
  Future<PlacementStep> answer({
    required String sessionId,
    required String itemId,
    required String answer,
  }) async {
    receivedAnswer = answer;
    if (error != null) {
      throw error!;
    }
    return step;
  }

  @override
  Future<PlacementResult> result(String sessionId) async {
    if (error != null) {
      throw error!;
    }
    return finalResult;
  }
}

void main() {
  late FakePlacementRepository repository;
  late PlacementViewModel viewModel;

  setUp(() {
    repository = FakePlacementRepository();
    viewModel = PlacementViewModel(repository);
  });

  test('start tạo session và hiển thị câu đầu tiên', () async {
    expect(await viewModel.start(), isTrue);

    expect(viewModel.sessionId, 'session-1');
    expect(viewModel.currentItem, firstItem);
    expect(viewModel.questionNumber, 1);
    expect(viewModel.isLoading, isFalse);
  });

  test('chọn đáp án rồi chuyển sang câu tiếp theo', () async {
    await viewModel.start();
    viewModel.selectAnswer('B');

    final completed = await viewModel.submitAnswer();

    expect(completed, isFalse);
    expect(repository.receivedAnswer, 'B');
    expect(viewModel.currentItem, secondItem);
    expect(viewModel.questionNumber, 2);
    expect(viewModel.selectedAnswer, isNull);
  });

  test('câu cuối tải result và đánh dấu hoàn thành', () async {
    repository.step = const PlacementStep(
      done: true,
      theta: 0.7,
      se: 0.3,
      cefr: 'B1',
    );
    await viewModel.start();
    viewModel.selectAnswer('A');

    final completed = await viewModel.submitAnswer();

    expect(completed, isTrue);
    expect(viewModel.currentItem, isNull);
    expect(viewModel.result?.cefr, 'B1');
    expect(viewModel.result?.itemsAnswered, 2);
  });

  test('map lỗi ml_service_unavailable thành thông báo tiếng Việt', () async {
    repository.error = const ApiException(
      statusCode: 503,
      code: 'ml_service_unavailable',
      message: 'ml_service_unavailable',
    );

    expect(await viewModel.start(), isFalse);
    expect(
      viewModel.errorMessage,
      'Dịch vụ chấm điểm tạm thời chưa sẵn sàng.',
    );
  });

  test('chặn gọi start hai lần khi request đang chạy', () async {
    repository.pendingStart = Completer<PlacementStart>();

    final first = viewModel.start();
    final second = await viewModel.start();

    expect(second, isFalse);
    expect(repository.startCalls, 1);
    repository.pendingStart!.complete(
      const PlacementStart(sessionId: 'session-1', item: firstItem),
    );
    expect(await first, isTrue);
  });
}
