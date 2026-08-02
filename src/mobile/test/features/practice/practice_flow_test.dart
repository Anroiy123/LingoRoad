import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/practice/data/practice_repository.dart';
import 'package:lingoroad_mobile/features/practice/data/speaking_recorder.dart';
import 'package:lingoroad_mobile/features/practice/domain/practice_models.dart';
import 'package:lingoroad_mobile/features/practice/presentation/practice_screen.dart';
import 'package:lingoroad_mobile/features/practice/presentation/practice_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../helpers/widget_test_harness.dart';

const writingResult = WritingResult(
  scores: WritingScores(
    taskAchievement: 6,
    coherenceCohesion: 6,
    lexicalResource: 5,
    grammaticalAccuracy: 5,
  ),
  feedback: [
    WritingFeedback(
      sentence: 'My hometown is Da Nang.',
      issue: 'Câu ngắn',
      suggestion: 'Thêm chi tiết',
    ),
  ],
  overallVi: 'Bài viết ổn.',
);

const speakingScore = SpeakingScore(
  transcript: 'I have lived here for two years.',
  accuracy: .9,
  completeness: 1,
  fluency: .8,
  total: .88,
  durationSeconds: 3,
  modelVersion: 'whisper-test',
  feedbackVi: 'Phát âm tốt.',
);

class FakePracticeRepository implements AiPracticeRepository {
  bool failAdvisorOnce = false;
  bool failSpeakingOnce = false;
  bool failHistoryOnce = false;
  int advisorCalls = 0;
  int speakingCalls = 0;
  int historyCalls = 0;
  Completer<String>? advisorCompleter;

  @override
  Future<String> askAdvisor(String question) async {
    advisorCalls++;
    if (advisorCompleter != null) return advisorCompleter!.future;
    if (failAdvisorOnce) {
      failAdvisorOnce = false;
      throw const ApiException(code: 'network_unavailable', message: 'offline');
    }
    return 'Ưu tiên ngữ pháp hiện tại hoàn thành.';
  }

  @override
  Future<WritingResult> evaluateWriting(
          String taskPrompt, String essay) async =>
      writingResult;

  @override
  Future<SpeakingScore> scoreSpeaking(
      String prompt, RecordedAudio audio) async {
    speakingCalls++;
    if (failSpeakingOnce) {
      failSpeakingOnce = false;
      throw const ApiException(code: 'ml_service_unavailable', message: 'down');
    }
    return speakingScore;
  }

  @override
  Future<List<SpeakingHistoryItem>> speakingHistory() async {
    historyCalls++;
    if (failHistoryOnce) {
      failHistoryOnce = false;
      throw const ApiException(code: 'network_unavailable', message: 'offline');
    }
    return const [];
  }
}

class FakeSpeakingRecorder implements SpeakingRecorder {
  bool permission = true;
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  bool disposed = false;

  @override
  Future<bool> start() async {
    startCalls++;
    return permission;
  }

  @override
  Future<RecordedAudio?> stop() async {
    stopCalls++;
    return RecordedAudio(
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'speaking.wav',
      mimeType: 'audio/wav',
    );
  }

  @override
  Future<void> cancel() async => cancelCalls++;

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  test('advisor có loading và chặn submit đồng thời', () async {
    final repository = FakePracticeRepository();
    final completer = Completer<String>();
    repository.advisorCompleter = completer;
    final vm = AiPracticeViewModel(repository, FakeSpeakingRecorder());

    final first = vm.askAdvisor('Tôi nên học gì?');
    final second = vm.askAdvisor('Câu hỏi trùng');
    expect(vm.advisorStatus, PracticeStatus.loading);
    expect(repository.advisorCalls, 1);
    completer.complete('Học ngữ pháp.');
    await Future.wait([first, second]);

    expect(vm.advisorStatus, PracticeStatus.success);
    expect(vm.advisorAnswer, 'Học ngữ pháp.');
    vm.dispose();
  });

  test('speaking giữ audio trong RAM để retry và không gửi hai lần', () async {
    final repository = FakePracticeRepository()..failSpeakingOnce = true;
    final recorder = FakeSpeakingRecorder();
    final vm = AiPracticeViewModel(repository, recorder);

    await vm.startRecording('Read this sentence');
    await Future.wait([vm.stopAndScore(), vm.stopAndScore()]);
    expect(recorder.stopCalls, 1);
    expect(repository.speakingCalls, 1);
    expect(vm.speakingStatus, PracticeStatus.error);

    await vm.retrySpeaking();
    expect(repository.speakingCalls, 2);
    expect(vm.speakingStatus, PracticeStatus.success);
    expect(vm.speakingScore?.modelVersion, 'whisper-test');
    vm.dispose();
  });

  test('speaking hiển thị lỗi khi quyền microphone bị từ chối', () async {
    final recorder = FakeSpeakingRecorder()..permission = false;
    final vm = AiPracticeViewModel(FakePracticeRepository(), recorder);

    await vm.startRecording('Read this');

    expect(vm.recording, isFalse);
    expect(vm.speakingError, 'microphone_permission_denied');
    expect(vm.canRetrySpeaking, isFalse);
    vm.dispose();
  });

  test('history có error và retry', () async {
    final repository = FakePracticeRepository()..failHistoryOnce = true;
    final vm = AiPracticeViewModel(repository, FakeSpeakingRecorder());

    await vm.loadHistory();
    expect(vm.historyStatus, PracticeStatus.error);
    await vm.loadHistory();
    expect(vm.historyStatus, PracticeStatus.success);
    expect(repository.historyCalls, 2);
    vm.dispose();
  });

  test('request hoàn tất sau dispose không phát notification', () async {
    final repository = FakePracticeRepository();
    final completer = Completer<String>();
    repository.advisorCompleter = completer;
    final vm = AiPracticeViewModel(repository, FakeSpeakingRecorder());
    final request = vm.askAdvisor('Tôi nên học gì?');

    vm.dispose();
    completer.complete('Học ngữ pháp.');
    await request;

    expect(vm.advisorAnswer, 'Học ngữ pháp.');
  });

  testWidgets('màn hình advisor render error và retry thành công',
      (tester) async {
    final repository = FakePracticeRepository()..failAdvisorOnce = true;
    final vm = AiPracticeViewModel(repository, FakeSpeakingRecorder());
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      ChangeNotifierProvider.value(
        value: vm,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AiPracticeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('advisor_question')), 'Tôi nên học gì?');
    await tester.tap(find.byKey(const Key('advisor_submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('network_unavailable'), findsOneWidget);

    await tester.tap(find.byKey(const Key('practice_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('advisor_answer')), findsOneWidget);
    expect(repository.advisorCalls, 2);
    vm.dispose();
  });
}
