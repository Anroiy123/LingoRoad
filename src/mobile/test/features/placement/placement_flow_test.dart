import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/app_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/placement/data/placement_repository.dart';
import 'package:lingoroad_mobile/features/placement/domain/placement_models.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_audio_player.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_question_screen.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_view_model.dart';
import 'package:lingoroad_mobile/main.dart';

class PlacementFlowAuthRepository implements AuthRepository {
  @override
  Future<String> login({
    required String email,
    required String password,
  }) async =>
      'token';

  @override
  Future<String> register({
    required String email,
    required String password,
    String? name,
  }) async =>
      'token';
}

class FlowPlacementRepository implements PlacementRepository {
  var answerCalls = 0;

  @override
  Future<PlacementStart> start() async => const PlacementStart(
        sessionId: 'session-1',
        item: PlacementItem(
          id: 'item-1',
          type: 'multiple_choice',
          stem: 'Choose the correct word.',
          options: ['go', 'goes'],
        ),
      );

  @override
  Future<PlacementStep> answer({
    required String sessionId,
    required String itemId,
    required String answer,
  }) async {
    answerCalls++;
    if (answerCalls == 1) {
      return const PlacementStep(
        done: false,
        item: PlacementItem(
          id: 'item-2',
          type: 'multiple_choice',
          stem: 'Choose the correct tense.',
          options: ['Past', 'Present'],
        ),
      );
    }
    return const PlacementStep(
      done: true,
      theta: 0.7,
      se: 0.3,
      cefr: 'B1',
    );
  }

  @override
  Future<PlacementResult> result(String sessionId) async =>
      const PlacementResult(
        theta: 0.7,
        se: 0.3,
        cefr: 'B1',
        itemsAnswered: 2,
        status: 'completed',
      );
}

class FakePlacementAudioPlayer implements PlacementAudioPlayer {
  String? playedUrl;

  @override
  Future<void> play(String url) async {
    playedUrl = url;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('hoàn thành intro, câu hỏi, kết quả rồi vào MainShell',
      (tester) async {
    final session = SessionController(MemorySessionStore('saved-token'));
    await session.restore();
    final router = createAppRouter(
      session: session,
      authRepository: PlacementFlowAuthRepository(),
      placementRepository: FlowPlacementRepository(),
    );

    await tester.pumpWidget(LingoRoadApp(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra trình độ đầu vào'), findsOneWidget);

    final startButton = find.byKey(const Key('placement_start'));
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    expect(find.text('Choose the correct word.'), findsOneWidget);
    expect(
      find.byKey(const Key('placement_answer_submit')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('placement_option_1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('placement_answer_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Choose the correct tense.'), findsOneWidget);
    expect(find.text('Câu 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('placement_option_0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('placement_answer_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Bạn đã hoàn thành!'), findsOneWidget);
    expect(find.byKey(const Key('placement_result_cefr')), findsOneWidget);
    expect(find.text('B1'), findsOneWidget);

    final continueButton = find.byKey(
      const Key('placement_result_continue'),
    );
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(find.text('Học'), findsOneWidget);
    router.dispose();
  });

  testWidgets('route câu hỏi trực tiếp quay về intro khi chưa có session',
      (tester) async {
    final session = SessionController(MemorySessionStore('saved-token'));
    await session.restore();
    final router = createAppRouter(
      session: session,
      authRepository: PlacementFlowAuthRepository(),
      placementRepository: FlowPlacementRepository(),
      initialLocation: '/placement/question',
    );

    await tester.pumpWidget(LingoRoadApp(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Kiểm tra trình độ đầu vào'), findsOneWidget);
    router.dispose();
  });

  testWidgets('câu listening phát audio URL đã chuẩn hóa', (tester) async {
    final audioPlayer = FakePlacementAudioPlayer();
    final listeningViewModel = PlacementViewModel(
      _ListeningPlacementRepository(),
    );
    await listeningViewModel.start();

    await tester.pumpWidget(
      MaterialApp(
        home: PlacementQuestionScreen(
          viewModel: listeningViewModel,
          audioPlayer: audioPlayer,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('placement_play_audio')));
    await tester.pump();

    expect(
      audioPlayer.playedUrl,
      'http://localhost:5000/audio/listening.mp3',
    );
  });
}

class _ListeningPlacementRepository implements PlacementRepository {
  @override
  Future<PlacementStart> start() async => const PlacementStart(
        sessionId: 'listening-session',
        item: PlacementItem(
          id: 'listening-item',
          type: 'listening',
          stem: 'What did you hear?',
          options: ['One', 'Two'],
          audioUrl: 'http://localhost:5000/audio/listening.mp3',
        ),
      );

  @override
  Future<PlacementStep> answer({
    required String sessionId,
    required String itemId,
    required String answer,
  }) =>
      throw UnimplementedError();

  @override
  Future<PlacementResult> result(String sessionId) =>
      throw UnimplementedError();
}
