import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/learning_path/data/learning_path_repository.dart';
import 'package:lingoroad_mobile/features/learning_path/domain/learning_path_models.dart';
import 'package:lingoroad_mobile/features/learning_path/presentation/learning_path_view_model.dart';
import 'package:lingoroad_mobile/features/lesson/data/lesson_repository.dart';
import 'package:lingoroad_mobile/features/lesson/domain/lesson_models.dart';
import 'package:lingoroad_mobile/features/lesson/presentation/lesson_screen.dart';
import 'package:lingoroad_mobile/features/lesson/presentation/lesson_view_model.dart';
import 'package:lingoroad_mobile/screens/learning_path_screen.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../helpers/widget_test_harness.dart';

const widgetStep = LearningPathStep(
  code: 'grammar.present-simple',
  name: 'Present simple',
  nameVi: 'Thì hiện tại đơn',
  cefr: 'A2',
  mastery: 0.35,
  reason: 'below_threshold',
  availability: 'current',
  sequence: 1,
);

const completedStep = LearningPathStep(
  code: 'grammar.completed',
  name: 'Completed skill',
  nameVi: 'Kỹ năng đã xong',
  cefr: 'A1',
  mastery: 1,
  reason: 'recommended',
  availability: 'completed',
  sequence: 1,
);

const lockedStep = LearningPathStep(
  code: 'grammar.locked',
  name: 'Locked skill',
  nameVi: 'Kỹ năng bị khóa',
  cefr: 'B1',
  mastery: 0,
  reason: 'not_started',
  availability: 'locked',
  sequence: 3,
);

const availableStep = LearningPathStep(
  code: 'grammar.available',
  name: 'Available skill',
  nameVi: 'Kỹ năng sẵn sàng',
  cefr: 'A1',
  mastery: 0,
  reason: 'not_started',
  availability: 'available',
  sequence: 2,
);

const routeExercise = LessonExercise(
  id: 'exercise-a1-articles',
  sequence: 1,
  type: 'mcq',
  stem: 'Choose the correct article: ___ apple.',
  options: ['a', 'an'],
  answered: false,
);

const routeAttempt = LessonAttempt(
  id: 'attempt-a1-articles',
  lessonId: 'lesson-a1-articles',
  slug: 'a1-articles',
  title: 'Articles',
  titleVi: 'Mạo từ',
  skillCode: 'grammar.present-simple',
  status: 'in_progress',
  exercises: [routeExercise],
);

const routeLesson = TodayLesson(
  id: 'lesson-a1-articles',
  slug: 'a1-articles',
  title: 'Articles',
  titleVi: 'Mạo từ',
  skillCode: 'grammar.present-simple',
  cefr: 'A2',
  itemCount: 1,
);

class ScreenLearningPathRepository implements LearningPathRepository {
  List<LearningPathStep> result = const [widgetStep];
  Object? error;

  @override
  Future<List<LearningPathStep>> fetch({int limit = 10}) async {
    if (error != null) {
      throw error!;
    }
    return result;
  }
}

class RoutedLessonRepository implements LessonRepository {
  RoutedLessonRepository({required this.todayLessons});

  final List<TodayLesson> todayLessons;
  final startedLessonIds = <String>[];
  int todayCalls = 0;

  @override
  Future<List<TodayLesson>> today() async {
    todayCalls++;
    return todayLessons;
  }

  @override
  Future<LessonAttempt> start(String lessonId, String operationId) async {
    startedLessonIds.add(lessonId);
    return routeAttempt;
  }

  @override
  Future<LessonAttempt> getAttempt(String attemptId) async => routeAttempt;

  @override
  Future<ExerciseFeedback> submit({
    required String exerciseId,
    required String answer,
    required String operationId,
  }) async => const ExerciseFeedback(correct: true, correctAnswer: 'an');

  @override
  Future<LessonCompletion> complete(
    String attemptId,
    String operationId,
  ) async => const LessonCompletion(
    correctAnswers: 1,
    totalAnswers: 1,
    reviewCardsCreated: 0,
  );
}

AppLanguageProvider loadLanguageProvider() {
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

Widget buildScreen(
  ScreenLearningPathRepository repository, {
  ThemeData? theme,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppLanguageProvider>.value(
        value: loadLanguageProvider(),
      ),
      ChangeNotifierProvider<LearningPathViewModel>(
        create: (_) => LearningPathViewModel(repository),
      ),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      home: const Scaffold(body: LearningPathScreen()),
    ),
  );
}

GoRouter learningPathRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(body: LearningPathScreen()),
    ),
    GoRoute(
      path: '/lesson/:id',
      builder: (context, state) => ChangeNotifierProvider(
        create: (_) => LessonViewModel(context.read<LessonRepository>()),
        child: LessonScreen(lessonId: state.pathParameters['id']!),
      ),
    ),
  ],
);

Widget buildRoutedScreen({
  required GoRouter router,
  required ScreenLearningPathRepository learningPathRepository,
  required RoutedLessonRepository lessonRepository,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppLanguageProvider>.value(
        value: loadLanguageProvider(),
      ),
      ChangeNotifierProvider<LearningPathViewModel>(
        create: (_) => LearningPathViewModel(learningPathRepository),
      ),
      Provider<LessonRepository>.value(value: lessonRepository),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  test('đọc availability và sequence do API lộ trình cung cấp', () {
    final step = LearningPathStep.fromJson({
      'code': 'grammar.current',
      'name': 'Current skill',
      'nameVi': 'Kỹ năng hiện tại',
      'cefr': 'A1',
      'mastery': .44,
      'reason': 'below_threshold',
      'availability': 'current',
      'sequence': 1,
    });

    expect(step.availability, 'current');
    expect(step.sequence, 1);
  });

  testWidgets('hiển thị dữ liệu thật và không còn XP/streak mock', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      buildScreen(ScreenLearningPathRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thì hiện tại đơn'), findsOneWidget);
    expect(find.text('A2 · Cần luyện thêm'), findsOneWidget);
    expect(find.text('1 kỹ năng được đề xuất'), findsOneWidget);
    expect(find.textContaining('XP'), findsNothing);
    expect(find.text('12'), findsNothing);
  });

  testWidgets('hiển thị empty state', (tester) async {
    final repository = ScreenLearningPathRepository()..result = const [];

    await pumpWidgetWithLingoRoadScreenUtil(tester, buildScreen(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('learning_path_empty')), findsOneWidget);
    expect(find.text('Lộ trình hiện đã hoàn tất'), findsOneWidget);
  });

  testWidgets('hiển thị lỗi và retry thành công', (tester) async {
    final repository = ScreenLearningPathRepository()
      ..error = const ApiException(
        code: 'network_unavailable',
        message: 'offline',
      );

    await pumpWidgetWithLingoRoadScreenUtil(tester, buildScreen(repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('learning_path_error')), findsOneWidget);

    repository.error = null;
    await tester.tap(find.byKey(const Key('learning_path_retry')));
    await tester.pumpAndSettle();

    expect(find.text('Thì hiện tại đơn'), findsOneWidget);
  });

  testWidgets('chọn kỹ năng mở lesson player tại route lesson khớp', (
    tester,
  ) async {
    final lessonRepository = RoutedLessonRepository(
      todayLessons: const [routeLesson],
    );
    final router = learningPathRouter();
    addTearDown(router.dispose);

    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      buildRoutedScreen(
        router: router,
        learningPathRepository: ScreenLearningPathRepository(),
        lessonRepository: lessonRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('learning_path_step_grammar.present-simple')),
    );
    await tester.pumpAndSettle();

    expect(lessonRepository.todayCalls, 1);
    expect(lessonRepository.startedLessonIds, ['lesson-a1-articles']);
    expect(find.byType(LessonScreen), findsOneWidget);
    expectRenderedTextSequence(
      find.byKey(const Key('lesson_stem')),
      'Choose the correct article: ___ apple.',
    );
  });

  testWidgets('kỹ năng chưa có lesson báo lỗi và không điều hướng', (
    tester,
  ) async {
    final lessonRepository = RoutedLessonRepository(todayLessons: const []);
    final router = learningPathRouter();
    addTearDown(router.dispose);

    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      buildRoutedScreen(
        router: router,
        learningPathRepository: ScreenLearningPathRepository(),
        lessonRepository: lessonRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('learning_path_step_grammar.present-simple')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Kỹ năng này chưa có bài học trong kế hoạch hôm nay.'),
      findsOneWidget,
    );
    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    expect(lessonRepository.startedLessonIds, isEmpty);
  });

  testWidgets(
    'Path phân biệt completed/current/locked và khóa có onTap null + disabled semantics',
    (tester) async {
      final repository = ScreenLearningPathRepository()
        ..result = const [completedStep, widgetStep, lockedStep];
      await pumpWidgetWithLingoRoadScreenUtil(tester, buildScreen(repository));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('learning_path_state_completed_grammar.completed'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('learning_path_state_current_grammar.present-simple'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('learning_path_state_locked_grammar.locked')),
        findsOneWidget,
      );

      final locked = tester.widget<InkWell>(
        find.byKey(const Key('learning_path_step_grammar.locked')),
      );
      expect(locked.onTap, isNull);

      final semantics = tester.getSemantics(
        find.byKey(const Key('learning_path_state_locked_grammar.locked')),
      );
      expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
      expect(semantics.label, contains('Kỹ năng bị khóa'));
    },
  );

  testWidgets('Path chỉ khoá theo availability API và giữ thứ tự server', (
    tester,
  ) async {
    final repository = ScreenLearningPathRepository()
      ..result = const [widgetStep, availableStep, lockedStep];
    await pumpWidgetWithLingoRoadScreenUtil(tester, buildScreen(repository));
    await tester.pumpAndSettle();

    final currentTop = tester
        .getTopLeft(
          find.byKey(const Key('learning_path_card_grammar.present-simple')),
        )
        .dy;
    final availableTop = tester
        .getTopLeft(
          find.byKey(const Key('learning_path_card_grammar.available')),
        )
        .dy;
    final lockedTop = tester
        .getTopLeft(find.byKey(const Key('learning_path_card_grammar.locked')))
        .dy;

    expect(currentTop, lessThan(availableTop));
    expect(availableTop, lessThan(lockedTop));
    expect(
      find.byKey(const Key('learning_path_state_unlocked_grammar.available')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('learning_path_state_locked_grammar.locked')),
      findsOneWidget,
    );
  });

  testWidgets('Path dark resolve màu current và locked theo ColorScheme', (
    tester,
  ) async {
    final repository = ScreenLearningPathRepository()
      ..result = const [completedStep, widgetStep, lockedStep];
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      buildScreen(repository, theme: AppTheme.dark),
    );
    await tester.pumpAndSettle();

    final scheme = AppTheme.dark.colorScheme;
    final progress = tester.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.elementAt(1).color, scheme.primary);
    expect(
      progress.elementAt(1).backgroundColor,
      scheme.surfaceContainerHighest,
    );

    final currentCard = tester.widget<Container>(
      find.byKey(const Key('learning_path_card_grammar.present-simple')),
    );
    final currentDecoration = currentCard.decoration! as BoxDecoration;
    expect(currentDecoration.color, scheme.surface);
    expect(
      currentDecoration.border,
      Border.fromBorderSide(BorderSide(color: scheme.primary, width: 2)),
    );

    final lockedCard = tester.widget<Container>(
      find.byKey(const Key('learning_path_card_grammar.locked')),
    );
    final lockedDecoration = lockedCard.decoration! as BoxDecoration;
    expect(lockedDecoration.color, scheme.surfaceContainerLow);
  });
}
