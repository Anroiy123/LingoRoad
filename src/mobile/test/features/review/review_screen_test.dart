import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/review/data/review_repository.dart';
import 'package:lingoroad_mobile/features/review/domain/review_models.dart';
import 'package:lingoroad_mobile/features/review/presentation/review_view_model.dart';
import 'package:lingoroad_mobile/features/question_review/data/question_review_repository.dart';
import 'package:lingoroad_mobile/features/question_review/domain/question_review_models.dart';
import 'package:lingoroad_mobile/features/question_review/presentation/question_review_view_model.dart';
import 'package:lingoroad_mobile/screens/review_screen.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../helpers/widget_test_harness.dart';

class FakeReviewRepository implements ReviewRepository {
  Object? error;

  @override
  Future<List<ReviewCard>> fetchDue() async {
    if (error != null) throw error!;
    return const [];
  }

  @override
  Future<void> grade({
    required ReviewCard card,
    required int rating,
    required String operationId,
  }) async {}
  @override
  Future<void> createCard(String skillCode, String front, String back) async {}
}

class FakeQuestionReviewRepository implements QuestionReviewRepository {
  QuestionReviewSession session = const QuestionReviewSession(
    items: [],
    totalDue: 3,
  );
  int calls = 0;
  Object? error;

  @override
  Future<QuestionReviewSession> fetchDue({int limit = 10}) async {
    calls++;
    if (error != null) throw error!;
    return session;
  }

  @override
  Future<QuestionReviewCheck> check({
    required QuestionReviewItem item,
    required String answer,
  }) => throw UnimplementedError();

  @override
  Future<QuestionReviewGrade> grade({
    required QuestionReviewItem item,
    required int rating,
    required String operationId,
    required int expectedReps,
    required String answer,
  }) => throw UnimplementedError();
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

void main() {
  testWidgets('ReviewScreen renders translated selection texts', (
    tester,
  ) async {
    final session = SessionController(MemorySessionStore('token'));
    await session.restore();
    final review = FakeReviewRepository();
    final l10n = _language();

    // Verify key translation works programmatically
    expect(l10n.translate('review.selection.title'), 'Lựa chọn ôn tập');
    expect(l10n.translate('review.selection.question_title'), 'Ôn tập câu hỏi');

    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<AppLanguageProvider>.value(value: l10n),
          ChangeNotifierProvider(create: (_) => ReviewViewModel(review)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ReviewScreen(active: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lựa chọn ôn tập'), findsOneWidget);
    expect(find.text('Ôn tập câu hỏi'), findsOneWidget);
    expect(find.text('Ôn tập từ vựng'), findsOneWidget);
  });

  testWidgets(
    'question badge is localized and reloads the server count after returning from question review',
    (tester) async {
      final session = SessionController(MemorySessionStore('token'));
      await session.restore();
      final words = FakeReviewRepository();
      final questions = FakeQuestionReviewRepository();
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const ReviewScreen()),
          GoRoute(
            path: '/question-review',
            builder: (context, state) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('return_from_question_review'),
                  onPressed: () => context.pop(),
                  child: const Text('return'),
                ),
              ),
            ),
          ),
        ],
      );
      await pumpWidgetWithLingoRoadScreenUtil(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: session),
            ChangeNotifierProvider<AppLanguageProvider>.value(
              value: _language(),
            ),
            ChangeNotifierProvider(create: (_) => ReviewViewModel(words)),
            ChangeNotifierProvider(
              create: (_) => QuestionReviewViewModel(questions),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 câu hỏi cần ôn'), findsOneWidget);

      await tester.tap(find.byKey(const Key('question_review_card')));
      await tester.pumpAndSettle();
      questions.session = const QuestionReviewSession(items: [], totalDue: 1);
      await tester.tap(find.byKey(const Key('return_from_question_review')));
      await tester.pumpAndSettle();

      expect(questions.calls, 2);
      expect(find.text('1 câu hỏi cần ôn'), findsOneWidget);
    },
  );

  testWidgets(
    'selection keeps failures inline instead of adding a third error card',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final session = SessionController(MemorySessionStore('token'));
      await session.restore();
      final words = FakeReviewRepository()
        ..error = const ApiException(
          code: 'network_unavailable',
          message: 'offline',
        );
      final questions = FakeQuestionReviewRepository()
        ..error = const ApiException(
          code: 'network_unavailable',
          message: 'offline',
        );

      await pumpWidgetWithLingoRoadScreenUtil(
        tester,
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: session),
            ChangeNotifierProvider<AppLanguageProvider>.value(
              value: _language(),
            ),
            ChangeNotifierProvider(create: (_) => ReviewViewModel(words)),
            ChangeNotifierProvider(
              create: (_) => QuestionReviewViewModel(questions),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: ReviewScreen(active: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Ôn tập câu hỏi, Không tải được'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.byType(AnimatedContainer), findsNWidgets(2));
      expect(find.text('Không thể tải thẻ ôn'), findsNothing);

      questions.error = null;
      await tester.tap(find.byKey(const Key('question_review_card')));
      await tester.pumpAndSettle();
      expect(questions.calls, greaterThanOrEqualTo(2));
      semantics.dispose();
    },
  );

  testWidgets('empty review sources render green completed cards', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final session = SessionController(MemorySessionStore('token'));
    await session.restore();
    final words = FakeReviewRepository();
    final questions = FakeQuestionReviewRepository()
      ..session = const QuestionReviewSession(items: [], totalDue: 0);

    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
          ChangeNotifierProvider(create: (_) => ReviewViewModel(words)),
          ChangeNotifierProvider(
            create: (_) => QuestionReviewViewModel(questions),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ReviewScreen(active: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Ôn tập câu hỏi, Đã hoàn thành'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Ôn tập từ vựng, Đã hoàn thành'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));

    for (final cardKey in const [
      Key('question_review_card'),
      Key('vocabulary_review_card'),
    ]) {
      final surfaceFinder = find.descendant(
        of: find.byKey(cardKey),
        matching: find.byType(AnimatedContainer),
      );
      expect(surfaceFinder, findsOneWidget);
      final surface = tester.widget<AnimatedContainer>(surfaceFinder);
      final decoration = surface.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(decoration.color, const Color(0xFFECFDF2));
      expect(border.top.color, AppColors.success);
    }
    semantics.dispose();
  });
}
