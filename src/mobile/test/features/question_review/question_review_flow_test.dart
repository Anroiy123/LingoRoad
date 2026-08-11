import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoroad_mobile/core/config/app_config.dart';
import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/question_review/data/question_review_repository.dart';
import 'package:lingoroad_mobile/features/question_review/domain/question_review_models.dart';
import 'package:lingoroad_mobile/features/question_review/presentation/question_review_screen.dart';
import 'package:lingoroad_mobile/features/question_review/presentation/question_review_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/exercise_answer_input.dart';
import 'package:provider/provider.dart';

import '../../helpers/widget_test_harness.dart';

const _first = QuestionReviewItem(
  id: '11111111-1111-1111-1111-111111111111',
  reps: 2,
  type: 'mcq',
  stem: 'Choose blue.',
  options: ['red', 'blue'],
);

const _second = QuestionReviewItem(
  id: '22222222-2222-2222-2222-222222222222',
  reps: 0,
  type: 'cloze',
  stem: 'The sky is ___.',
  options: [],
);

const _third = QuestionReviewItem(
  id: '33333333-3333-3333-3333-333333333333',
  reps: 1,
  type: 'reorder',
  stem: 'Arrange the sentence.',
  options: ['I', 'learn', 'English'],
);

class _FakeQuestionReviewRepository implements QuestionReviewRepository {
  QuestionReviewSession session = const QuestionReviewSession(
    items: [_first, _second, _third],
    totalDue: 13,
  );
  Object? loadError;
  Object? checkError;
  Object? gradeError;
  Completer<QuestionReviewCheck>? pendingCheck;
  Completer<QuestionReviewGrade>? pendingGrade;
  Completer<QuestionReviewSession>? pendingFetch;
  int fetchCalls = 0;
  final fetchSessions = <QuestionReviewSession>[];
  final checks = <String>[];
  final grades =
      <({String answer, int expectedReps, int rating, String operationId})>[];

  @override
  Future<QuestionReviewSession> fetchDue({int limit = 10}) async {
    fetchCalls++;
    if (loadError != null) throw loadError!;
    if (pendingFetch != null) return pendingFetch!.future;
    if (fetchSessions.isNotEmpty) return fetchSessions.removeAt(0);
    return session;
  }

  @override
  Future<QuestionReviewCheck> check({
    required QuestionReviewItem item,
    required String answer,
  }) async {
    checks.add(answer);
    if (checkError != null) throw checkError!;
    if (pendingCheck != null) return pendingCheck!.future;
    final correctAnswer = item.type == 'reorder' ? 'I learn English' : 'blue';
    return QuestionReviewCheck(
      correct: answer.trim().toLowerCase() == correctAnswer.toLowerCase(),
      correctAnswer: correctAnswer,
      explanationVi: 'Blue là màu của bầu trời.',
    );
  }

  @override
  Future<QuestionReviewGrade> grade({
    required QuestionReviewItem item,
    required int rating,
    required String operationId,
    required int expectedReps,
    required String answer,
  }) async {
    grades.add((
      answer: answer,
      expectedReps: expectedReps,
      rating: rating,
      operationId: operationId,
    ));
    if (gradeError != null) throw gradeError!;
    if (pendingGrade != null) return pendingGrade!.future;
    return const QuestionReviewGrade(xp: 5, coins: 1);
  }
}

AppLanguageProvider _language() {
  final vi =
      json.decode(File('assets/translations/vi.json').readAsStringSync())
          as Map<String, dynamic>;
  final en =
      json.decode(File('assets/translations/en.json').readAsStringSync())
          as Map<String, dynamic>;
  return AppLanguageProvider.test(
    translations: {AppLanguage.vi: vi, AppLanguage.en: en},
  );
}

Widget _app(_FakeQuestionReviewRepository repository) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
    ChangeNotifierProvider(create: (_) => QuestionReviewViewModel(repository)),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const QuestionReviewScreen()),
);

Widget _routedApp(_FakeQuestionReviewRepository repository) {
  final router = GoRouter(
    initialLocation: '/question-review',
    routes: [
      GoRoute(
        path: '/question-review',
        builder: (_, _) => const QuestionReviewScreen(),
      ),
      GoRoute(
        path: '/review',
        builder: (_, _) => const Scaffold(body: Text('review destination')),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
      ChangeNotifierProvider(
        create: (_) => QuestionReviewViewModel(repository),
      ),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  test(
    'question-review parses due payload separately from saved-word cards',
    () {
      final session = QuestionReviewSession.fromJson({
        'totalDue': 11,
        'items': [
          {
            'id': _first.id,
            'reps': 2,
            'type': 'mcq',
            'stem': 'Choose blue.',
            'options': ['red', 'blue'],
          },
        ],
      });
      expect(session.totalDue, 11);
      expect(session.items.single.type, 'mcq');
      expect(
        () => QuestionReviewSession.fromJson({'totalDue': 1}),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test(
    'question-review repository uses only /reviews routes and grade snapshot',
    () async {
      final session = SessionController(MemorySessionStore('jwt'));
      await session.restore();
      final repository = ApiQuestionReviewRepository(
        ApiClient(
          config: AppConfig(apiBaseUrl: 'http://localhost:5000'),
          session: session,
          httpClient: MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer jwt');
            if (request.method == 'GET') {
              expect(request.url.path, '/reviews/questions/due');
              expect(request.url.queryParameters['limit'], '10');
              return http.Response(
                '{"items":[{"id":"${_first.id}","reps":2,"type":"mcq","stem":"Choose blue.","options":["red","blue"]}],"totalDue":1}',
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path.endsWith('/check')) {
              expect(request.method, 'POST');
              expect(json.decode(request.body), {'answer': 'blue'});
              return http.Response(
                '{"correct":true,"correctAnswer":"blue"}',
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            expect(request.method, 'POST');
            expect(request.url.path, '/reviews/${_first.id}/grade');
            expect(json.decode(request.body), {
              'rating': 3,
              'operationId': '11111111-1111-4111-8111-111111111111',
              'expectedReps': 2,
              'answer': 'blue',
            });
            return http.Response(
              '{"xp":5,"coins":1}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      final due = await repository.fetchDue();
      final item = due.items.single;
      expect(
        (await repository.check(item: item, answer: 'blue')).correct,
        isTrue,
      );
      final grade = await repository.grade(
        item: item,
        rating: 3,
        expectedReps: item.reps,
        answer: 'blue',
        operationId: '11111111-1111-4111-8111-111111111111',
      );
      expect(grade.xp, 5);
    },
  );

  test(
    'state machine keeps answer and operation id across check and grade retries',
    () async {
      final repository = _FakeQuestionReviewRepository();
      final vm = QuestionReviewViewModel(repository);

      await vm.load();
      expect(vm.state, QuestionReviewState.ready);
      expect(vm.dueCount, 13);
      vm.setAnswer(' blue ');
      repository.checkError = const ApiException(
        code: 'network_unavailable',
        message: 'offline',
      );
      await vm.check();
      expect(vm.state, QuestionReviewState.error);
      expect(vm.answer, ' blue ');

      repository.checkError = null;
      await vm.retry();
      expect(vm.state, QuestionReviewState.feedback);
      expect(vm.feedback!.correct, isTrue);
      repository.gradeError = const ApiException(
        code: 'request_timeout',
        message: 'unknown',
      );
      await vm.grade(2);
      final operationId = repository.grades.single.operationId;
      expect(vm.state, QuestionReviewState.error);
      expect(vm.answer, ' blue ');

      repository.gradeError = null;
      await vm.retry();
      expect(repository.grades.last.operationId, operationId);
      expect(repository.grades.last.expectedReps, 2);
      expect(repository.grades.last.rating, 2);
      expect(vm.completed, 1);
    },
  );

  test(
    'wrong answer is auto-graded once with rating one and completion totals rewards',
    () async {
      final repository = _FakeQuestionReviewRepository()
        ..session = const QuestionReviewSession(items: [_first], totalDue: 1);
      final vm = QuestionReviewViewModel(repository);
      await vm.load();
      vm.setAnswer('red');
      await vm.check();

      expect(vm.state, QuestionReviewState.feedback);
      expect(vm.feedback!.correct, isFalse);
      expect(repository.grades.single.rating, 1);
      expect(repository.grades.single.answer, 'red');
      await vm.next();
      expect(vm.state, QuestionReviewState.complete);
      expect(vm.correctCount, 0);
      expect(vm.incorrectCount, 1);
      expect(vm.xp, 5);
      expect(vm.coins, 1);
    },
  );

  test('checking is single-flight', () async {
    final repository = _FakeQuestionReviewRepository()
      ..pendingCheck = Completer<QuestionReviewCheck>();
    final vm = QuestionReviewViewModel(repository);
    await vm.load();
    vm.setAnswer('blue');
    final first = vm.check();
    await vm.check();
    expect(repository.checks, ['blue']);
    repository.pendingCheck!.complete(
      const QuestionReviewCheck(correct: true, correctAnswer: 'blue'),
    );
    await first;
  });

  test(
    'stale check and grade responses reload the due queue instead of retrying the stale card',
    () async {
      final repository = _FakeQuestionReviewRepository();
      final vm = QuestionReviewViewModel(repository);
      await vm.load();
      repository.session = const QuestionReviewSession(items: [], totalDue: 0);
      repository.checkError = const ApiException(
        code: 'review_not_due',
        message: 'stale',
        statusCode: 409,
      );
      vm.setAnswer('blue');
      await vm.check();
      expect(repository.fetchCalls, 2);
      expect(vm.state, QuestionReviewState.empty);

      repository.session = const QuestionReviewSession(
        items: [_first],
        totalDue: 1,
      );
      repository.checkError = null;
      await vm.load();
      vm.setAnswer('blue');
      await vm.check();
      repository.session = const QuestionReviewSession(items: [], totalDue: 0);
      repository.gradeError = const ApiException(
        code: 'review_already_graded',
        message: 'stale',
        statusCode: 409,
      );
      await vm.grade(3);
      expect(repository.fetchCalls, 4);
      expect(vm.state, QuestionReviewState.empty);
    },
  );

  test(
    'stale reload keeps rewards already earned in the current session',
    () async {
      final repository = _FakeQuestionReviewRepository()
        ..session = const QuestionReviewSession(
          items: [_first, _second],
          totalDue: 2,
        );
      final vm = QuestionReviewViewModel(repository);
      await vm.load();
      vm.setAnswer('blue');
      await vm.check();
      await vm.grade(3);
      expect(vm.correctCount, 1);
      expect(vm.xp, 5);

      repository.session = const QuestionReviewSession(items: [], totalDue: 0);
      repository.checkError = const ApiException(
        code: 'review_not_due',
        message: 'stale',
        statusCode: 409,
      );
      vm.setAnswer('blue');
      await vm.check();
      expect(vm.state, QuestionReviewState.empty);
      expect(vm.correctCount, 1);
      expect(vm.xp, 5);
    },
  );

  test(
    'stale grade excludes the current provisional result but keeps prior successful grades',
    () async {
      final repository = _FakeQuestionReviewRepository()
        ..session = const QuestionReviewSession(
          items: [_first, _second],
          totalDue: 2,
        );
      final vm = QuestionReviewViewModel(repository);
      await vm.load();

      vm.setAnswer('blue');
      await vm.check();
      await vm.grade(3);
      expect(vm.correctCount, 1);
      expect(vm.xp, 5);
      expect(vm.coins, 1);

      repository.session = const QuestionReviewSession(items: [], totalDue: 0);
      repository.gradeError = const ApiException(
        code: 'review_already_graded',
        message: 'stale',
        statusCode: 409,
      );
      vm.setAnswer('blue');
      await vm.check();
      await vm.grade(3);

      expect(vm.state, QuestionReviewState.empty);
      expect(vm.correctCount, 1);
      expect(vm.incorrectCount, 0);
      expect(vm.xp, 5);
      expect(vm.coins, 1);
    },
  );

  test('grading is single-flight while a rating request is pending', () async {
    final repository = _FakeQuestionReviewRepository()
      ..pendingGrade = Completer<QuestionReviewGrade>();
    final vm = QuestionReviewViewModel(repository);
    await vm.load();
    vm.setAnswer('blue');
    await vm.check();
    final first = vm.grade(3);
    await vm.grade(3);
    expect(repository.grades, hasLength(1));
    repository.pendingGrade!.complete(
      const QuestionReviewGrade(xp: 5, coins: 1),
    );
    await first;
    expect(vm.completed, 1);
  });

  testWidgets(
    'reorder input treats duplicate tokens as separate option instances',
    (tester) async {
      final answers = <String>[];
      await pumpWidgetWithLingoRoadScreenUtil(
        tester,
        MaterialApp(
          home: Scaffold(
            body: ExerciseAnswerInput(
              type: 'reorder',
              options: const ['had', 'had', 'enough'],
              answer: '',
              enabled: true,
              onAnswerChanged: answers.add,
              onSubmit: (_) {},
              textFieldKey: const Key('text'),
              submitKey: const Key('submit'),
              submitLabel: 'Check',
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('answer_reorder_0')), findsOneWidget);
      expect(find.byKey(const Key('answer_reorder_1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('answer_reorder_0')));
      await tester.tap(find.byKey(const Key('answer_reorder_1')));
      expect(answers.last, 'had had');
    },
  );

  testWidgets(
    'reorder feedback question review công bố đúng và tô trạng thái đúng',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = _FakeQuestionReviewRepository()
        ..session = const QuestionReviewSession(items: [_third], totalDue: 1);
      await pumpWidgetWithLingoRoadScreenUtil(tester, _app(repository));
      await tester.pumpAndSettle();

      for (final index in [0, 1, 2]) {
        await tester.tap(find.byKey(Key('answer_reorder_$index')));
      }
      await tester.pump();
      await tester.tap(find.byKey(const Key('question_review_check')));
      await tester.pumpAndSettle();

      final feedback = tester.widget<Semantics>(
        find.byKey(const Key('answer_reorder_feedback')),
      );
      expect(feedback.properties.liveRegion, isTrue);
      expect(feedback.properties.label, 'đáp án đúng');
      final selected = tester.widget<Semantics>(
        find.byKey(const Key('answer_reorder_semantics_0')),
      );
      expect(selected.properties.selected, isTrue);
      expect(selected.properties.label, 'I, đáp án đúng');
      semantics.dispose();
    },
  );

  testWidgets(
    'reorder feedback question review công bố sai và tô trạng thái sai',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = _FakeQuestionReviewRepository()
        ..session = const QuestionReviewSession(items: [_third], totalDue: 1);
      await pumpWidgetWithLingoRoadScreenUtil(tester, _app(repository));
      await tester.pumpAndSettle();

      for (final index in [1, 0, 2]) {
        await tester.tap(find.byKey(Key('answer_reorder_$index')));
      }
      await tester.pump();
      await tester.tap(find.byKey(const Key('question_review_check')));
      await tester.pumpAndSettle();

      final feedback = tester.widget<Semantics>(
        find.byKey(const Key('answer_reorder_feedback')),
      );
      expect(feedback.properties.liveRegion, isTrue);
      expect(feedback.properties.label, 'lựa chọn chưa đúng');
      final selected = tester.widget<Semantics>(
        find.byKey(const Key('answer_reorder_semantics_0')),
      );
      expect(selected.properties.selected, isTrue);
      expect(selected.properties.label, 'I, lựa chọn chưa đúng');
      semantics.dispose();
    },
  );

  testWidgets(
    'load failure uses neutral error copy while an answer operation retains its answer',
    (tester) async {
      final repository = _FakeQuestionReviewRepository()
        ..loadError = const ApiException(
          code: 'network_unavailable',
          message: 'offline',
        );
      await pumpWidgetWithLingoRoadScreenUtil(tester, _app(repository));
      await tester.pumpAndSettle();
      expect(find.text('Không thể tải câu hỏi cần ôn.'), findsOneWidget);
    },
  );

  testWidgets(
    'operation failure tells the learner the submitted answer is retained',
    (tester) async {
      final repository = _FakeQuestionReviewRepository()
        ..checkError = const ApiException(
          code: 'network_unavailable',
          message: 'offline',
        );
      await pumpWidgetWithLingoRoadScreenUtil(tester, _app(repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('answer_option_blue')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('question_review_check')));
      await tester.pumpAndSettle();
      expect(
        find.text('Câu trả lời của bạn vẫn được giữ. Hãy thử lại.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'completion refreshes due count and shows Ôn thêm for a newly re-due card',
    (tester) async {
      final repository = _FakeQuestionReviewRepository()
        ..fetchSessions.addAll(const [
          QuestionReviewSession(items: [_first], totalDue: 1),
          QuestionReviewSession(items: [_first], totalDue: 1),
        ]);
      await pumpWidgetWithLingoRoadScreenUtil(tester, _app(repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('answer_option_red')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('question_review_check')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('question_review_next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('question_review_complete')), findsOneWidget);
      expect(find.text('Ôn thêm'), findsOneWidget);
      expect(repository.fetchCalls, 2);
    },
  );

  test(
    'response from an old account cannot populate the new session',
    () async {
      final repository = _FakeQuestionReviewRepository()
        ..pendingFetch = Completer<QuestionReviewSession>();
      final vm = QuestionReviewViewModel(repository, sessionGeneration: 1);

      final oldLoad = vm.load();
      vm.updateSessionGeneration(2);
      repository.pendingFetch!.complete(
        const QuestionReviewSession(items: [_first], totalDue: 1),
      );
      await oldLoad;

      expect(vm.sessionGeneration, 2);
      expect(vm.state, QuestionReviewState.initial);
      expect(vm.current, isNull);
      expect(vm.dueCount, 0);

      repository.pendingFetch = null;
      repository.session = const QuestionReviewSession(
        items: [_second],
        totalDue: 1,
      );
      await vm.load();
      expect(vm.current, _second);

      repository.pendingCheck = Completer<QuestionReviewCheck>();
      vm.setAnswer('blue');
      final oldCheck = vm.check();
      vm.updateSessionGeneration(3);
      repository.pendingCheck!.complete(
        const QuestionReviewCheck(correct: true, correctAnswer: 'blue'),
      );
      await oldCheck;
      expect(vm.sessionGeneration, 3);
      expect(vm.state, QuestionReviewState.initial);
      expect(vm.feedback, isNull);
    },
  );

  testWidgets('completion returns to the Review screen', (tester) async {
    final repository = _FakeQuestionReviewRepository()
      ..session = const QuestionReviewSession(items: [_first], totalDue: 1);
    await pumpWidgetWithLingoRoadScreenUtil(tester, _routedApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('answer_option_red')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('question_review_check')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('question_review_next')));
    await tester.pumpAndSettle();

    expect(find.text('Về Ôn tập'), findsOneWidget);
    await tester.tap(find.byKey(const Key('question_review_return')));
    await tester.pumpAndSettle();
    expect(find.text('review destination'), findsOneWidget);
  });

  testWidgets(
    'MCQ, cloze and reorder accept answers without exposing feedback before check',
    (tester) async {
      final repository = _FakeQuestionReviewRepository();
      await pumpWidgetWithLingoRoadScreenUtil(tester, _app(repository));
      await tester.pumpAndSettle();

      expect(find.text('blue'), findsOneWidget);
      expect(find.text('Blue là màu của bầu trời.'), findsNothing);
      expect(find.byKey(const Key('question_review_feedback')), findsNothing);
      await tester.tap(find.byKey(const Key('answer_option_blue')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('question_review_check')));
      await tester.pumpAndSettle();
      expect(find.text('Blue là màu của bầu trời.'), findsOneWidget);
      expect(find.byKey(const Key('question_review_feedback')), findsOneWidget);
      final feedback = tester.widget<Semantics>(
        find.byKey(const Key('question_review_feedback')).first,
      );
      expect(feedback.properties.liveRegion, isTrue);
      expect(
        tester
            .widget<Focus>(
              find
                  .descendant(
                    of: find.byKey(const Key('question_review_feedback')).first,
                    matching: find.byType(Focus),
                  )
                  .first,
            )
            .focusNode
            ?.hasFocus,
        isTrue,
      );

      await tester.tap(find.byKey(const Key('question_review_rating_3')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('question_review_text_answer')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('question_review_text_answer')),
        'blue',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('question_review_check')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('question_review_rating_2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('answer_reorder_0')), findsOneWidget);
      await tester.tap(find.byKey(const Key('answer_reorder_0')));
      await tester.tap(find.byKey(const Key('answer_reorder_1')));
      await tester.tap(find.byKey(const Key('answer_reorder_2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('question_review_check')));
      await tester.pumpAndSettle();
      expect(repository.checks.last, 'I learn English');
    },
  );

  testWidgets('long question and feedback remain reachable by scrolling', (
    tester,
  ) async {
    final longStem = List.filled(40, 'A long question sentence.').join(' ');
    final longExplanation = List.filled(
      50,
      'A detailed explanation.',
    ).join(' ');
    final repository = _FakeQuestionReviewRepository()
      ..session = QuestionReviewSession(
        items: [
          QuestionReviewItem(
            id: _first.id,
            reps: 0,
            type: 'mcq',
            stem: longStem,
            options: const ['red', 'blue'],
          ),
        ],
        totalDue: 1,
      );
    repository.pendingCheck = Completer<QuestionReviewCheck>();

    await pumpWidgetWithLingoRoadScreenUtil(tester, _app(repository));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('question_review_question_scroll')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('question_review_check')));
    await tester.tap(find.byKey(const Key('answer_option_blue')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('question_review_check')));
    await tester.tap(find.byKey(const Key('question_review_check')));
    repository.pendingCheck!.complete(
      QuestionReviewCheck(
        correct: true,
        correctAnswer: 'blue',
        explanationVi: longExplanation,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('question_review_feedback_scroll')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const Key('question_review_rating_3')),
    );
    expect(find.byKey(const Key('question_review_rating_3')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
