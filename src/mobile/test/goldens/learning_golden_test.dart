import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:lingoroad_mobile/features/dashboard/domain/dashboard_models.dart';
import 'package:lingoroad_mobile/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:lingoroad_mobile/features/learning_path/data/learning_path_repository.dart';
import 'package:lingoroad_mobile/features/learning_path/domain/learning_path_models.dart';
import 'package:lingoroad_mobile/features/learning_path/presentation/learning_path_view_model.dart';
import 'package:lingoroad_mobile/features/lesson/data/lesson_repository.dart';
import 'package:lingoroad_mobile/features/lesson/domain/lesson_models.dart';
import 'package:lingoroad_mobile/features/lesson/presentation/lesson_screen.dart';
import 'package:lingoroad_mobile/features/lesson/presentation/lesson_view_model.dart';
import 'package:lingoroad_mobile/features/question_review/data/question_review_repository.dart';
import 'package:lingoroad_mobile/features/question_review/domain/question_review_models.dart';
import 'package:lingoroad_mobile/features/question_review/presentation/question_review_screen.dart';
import 'package:lingoroad_mobile/features/question_review/presentation/question_review_view_model.dart';
import 'package:lingoroad_mobile/features/review/data/review_repository.dart';
import 'package:lingoroad_mobile/features/review/domain/review_models.dart';
import 'package:lingoroad_mobile/features/review/presentation/review_view_model.dart';
import 'package:lingoroad_mobile/screens/home_screen.dart';
import 'package:lingoroad_mobile/screens/learning_path_screen.dart';
import 'package:lingoroad_mobile/screens/vocabulary_review_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/widget_test_harness.dart';

/// This flag is deliberately opt-in so Windows can generate inspection images
/// without ever comparing them in the Linux-only CI suite. The committed
/// baselines are replaced from the existing Ubuntu failure artifact.
const _allowWindowsGoldenUpdate = bool.fromEnvironment(
  'LINGOROAD_UPDATE_GOLDENS',
);

enum _LearningSurface {
  home,
  pathLoaded,
  pathEmpty,
  pathError,
  lessonExercise,
  lessonFeedbackCorrect,
  lessonFeedbackIncorrect,
  lessonComplete,
  questionReady,
  questionFeedbackCorrect,
  questionFeedbackIncorrect,
  questionEmpty,
  questionError,
  questionComplete,
  vocabularyReady,
  vocabularyBack,
  vocabularyEmpty,
  vocabularyError,
  vocabularyComplete,
}

extension on _LearningSurface {
  String get goldenName => switch (this) {
    _LearningSurface.home => 'home_loaded',
    _LearningSurface.pathLoaded => 'learning_path_loaded',
    _LearningSurface.pathEmpty => 'learning_path_empty',
    _LearningSurface.pathError => 'learning_path_error',
    _LearningSurface.lessonExercise => 'lesson_exercise',
    _LearningSurface.lessonFeedbackCorrect => 'lesson_feedback_correct',
    _LearningSurface.lessonFeedbackIncorrect => 'lesson_feedback_incorrect',
    _LearningSurface.lessonComplete => 'lesson_complete',
    _LearningSurface.questionReady => 'question_review_ready',
    _LearningSurface.questionFeedbackCorrect =>
      'question_review_feedback_correct',
    _LearningSurface.questionFeedbackIncorrect =>
      'question_review_feedback_incorrect',
    _LearningSurface.questionEmpty => 'question_review_empty',
    _LearningSurface.questionError => 'question_review_error',
    _LearningSurface.questionComplete => 'question_review_complete',
    _LearningSurface.vocabularyReady => 'vocabulary_review_ready',
    _LearningSurface.vocabularyBack => 'vocabulary_review_back',
    _LearningSurface.vocabularyEmpty => 'vocabulary_review_empty',
    _LearningSurface.vocabularyError => 'vocabulary_review_error',
    _LearningSurface.vocabularyComplete => 'vocabulary_review_complete',
  };
}

const _lessonExercise = LessonExercise(
  id: 'golden-exercise',
  sequence: 1,
  type: 'mcq',
  stem: 'Lan ___ English every day.',
  options: ['study', 'studies'],
  answered: false,
);

const _lessonAttempt = LessonAttempt(
  id: 'golden-attempt',
  lessonId: 'golden-lesson',
  slug: 'present-simple',
  title: 'Present simple',
  titleVi: 'Thì hiện tại đơn',
  skillCode: 'grammar.present-simple',
  status: 'in_progress',
  exercises: [_lessonExercise],
);

const _question = QuestionReviewItem(
  id: '11111111-1111-1111-1111-111111111111',
  reps: 2,
  type: 'mcq',
  stem: 'Choose blue.',
  options: ['red', 'blue'],
);

const _pathSteps = [
  LearningPathStep(
    code: 'grammar.completed',
    name: 'Completed skill',
    nameVi: 'Kỹ năng đã xong',
    cefr: 'A1',
    mastery: 1,
    reason: 'recommended',
  ),
  LearningPathStep(
    code: 'grammar.present-simple',
    name: 'Present simple',
    nameVi: 'Thì hiện tại đơn',
    cefr: 'A2',
    mastery: .35,
    reason: 'below_threshold',
  ),
  LearningPathStep(
    code: 'grammar.locked',
    name: 'Locked skill',
    nameVi: 'Kỹ năng bị khóa',
    cefr: 'B1',
    mastery: 0,
    reason: 'not_started',
  ),
];

const _dashboard = DashboardData(
  name: 'Mai',
  currentCefr: 'A2',
  targetCefr: 'B1',
  dailyGoalMinutes: 30,
  mastery: .42,
  dailyProgress: .5,
  weeklyProgress: .25,
  dueReviews: 3,
  completedLessons: 2,
  xp: 125,
  coins: 7,
  currentStreak: 4,
  longestStreak: 6,
  activeDates: [],
  todayLesson: TodayLesson(
    id: 'golden-lesson',
    slug: 'present-simple',
    title: 'Present simple',
    titleVi: 'Hiện tại đơn',
    skillCode: 'grammar.present-simple',
    cefr: 'A2',
    itemCount: 5,
  ),
  recentActivity: [],
);

class _DashboardRepository implements DashboardRepository {
  @override
  Future<DashboardData> dashboard() async => _dashboard;

  @override
  Future<List<QuestData>> quests() async => const [
    QuestData(code: 'daily_lesson', current: 0, target: 1, completed: false),
    QuestData(code: 'daily_xp', current: 20, target: 50, completed: false),
  ];
}

class _PathRepository implements LearningPathRepository {
  _PathRepository({this.steps = _pathSteps, this.error});

  final List<LearningPathStep> steps;
  final Object? error;

  @override
  Future<List<LearningPathStep>> fetch({int limit = 10}) async {
    if (error != null) throw error!;
    return steps;
  }
}

class _LessonRepository implements LessonRepository {
  _LessonRepository({required this.correct});

  final bool correct;

  @override
  Future<LessonAttempt> start(String lessonId, String operationId) async =>
      _lessonAttempt;

  @override
  Future<LessonAttempt> getAttempt(String attemptId) async => _lessonAttempt;

  @override
  Future<ExerciseFeedback> submit({
    required String exerciseId,
    required String answer,
    required String operationId,
  }) async => ExerciseFeedback(
    correct: correct,
    correctAnswer: 'studies',
    explanationVi: correct
        ? 'Động từ thêm -ies với Lan.'
        : 'Đáp án đúng là studies.',
  );

  @override
  Future<LessonCompletion> complete(
    String attemptId,
    String operationId,
  ) async => const LessonCompletion(
    correctAnswers: 1,
    totalAnswers: 1,
    reviewCardsCreated: 1,
  );

  @override
  Future<List<TodayLesson>> today() async => const [];
}

class _QuestionRepository implements QuestionReviewRepository {
  _QuestionRepository({
    this.items = const [_question],
    this.totalDue = 1,
    this.error,
  });

  final List<QuestionReviewItem> items;
  final int totalDue;
  final Object? error;

  @override
  Future<QuestionReviewSession> fetchDue({int limit = 10}) async {
    if (error != null) throw error!;
    return QuestionReviewSession(items: items, totalDue: totalDue);
  }

  @override
  Future<QuestionReviewCheck> check({
    required QuestionReviewItem item,
    required String answer,
  }) async => QuestionReviewCheck(
    correct: answer.trim().toLowerCase() == 'blue',
    correctAnswer: 'blue',
    explanationVi: 'Blue là màu của bầu trời.',
  );

  @override
  Future<QuestionReviewGrade> grade({
    required QuestionReviewItem item,
    required int rating,
    required String operationId,
    required int expectedReps,
    required String answer,
  }) async => const QuestionReviewGrade(xp: 5, coins: 1);
}

class _ReviewRepository implements ReviewRepository {
  _ReviewRepository({this.cards = const [], this.error});

  final List<ReviewCard> cards;
  final Object? error;

  @override
  Future<List<ReviewCard>> fetchDue() async {
    if (error != null) throw error!;
    return cards;
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

AppLanguageProvider _language() {
  final vi =
      json.decode(File('assets/translations/vi.json').readAsStringSync())
          as Map<String, dynamic>;
  final en =
      json.decode(File('assets/translations/en.json').readAsStringSync())
          as Map<String, dynamic>;
  return AppLanguageProvider.test(
    translations: {AppLanguage.vi: vi, AppLanguage.en: en},
    currentLanguage: AppLanguage.vi,
  );
}

Widget _home() => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
    ChangeNotifierProvider(
      create: (_) => DashboardViewModel(_DashboardRepository()),
    ),
  ],
  child: const Scaffold(body: HomeScreen()),
);

Widget _path(_PathRepository repository) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
    ChangeNotifierProvider(create: (_) => LearningPathViewModel(repository)),
  ],
  child: const Scaffold(body: LearningPathScreen()),
);

Widget _lesson(bool correct) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
    ChangeNotifierProvider(
      create: (_) => LessonViewModel(_LessonRepository(correct: correct)),
    ),
  ],
  child: const LessonScreen(lessonId: 'golden-lesson'),
);

Widget _questions(_QuestionRepository repository) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
    ChangeNotifierProvider(create: (_) => QuestionReviewViewModel(repository)),
  ],
  child: const QuestionReviewScreen(),
);

Widget _vocabulary(_ReviewRepository repository) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
    ChangeNotifierProvider(create: (_) => ReviewViewModel(repository)),
  ],
  child: const VocabularyReviewScreen(),
);

Future<void> _pumpSurface(
  WidgetTester tester,
  _LearningSurface surface,
  ThemeMode mode, {
  Size size = lingoRoadDesignSize,
  double textScaleFactor = 1,
}) async {
  final child = switch (surface) {
    _LearningSurface.home => _home(),
    _LearningSurface.pathLoaded => _path(_PathRepository()),
    _LearningSurface.pathEmpty => _path(_PathRepository(steps: const [])),
    _LearningSurface.pathError => _path(
      _PathRepository(
        error: const ApiException(
          code: 'network_unavailable',
          message: 'offline',
        ),
      ),
    ),
    _LearningSurface.lessonExercise ||
    _LearningSurface.lessonFeedbackCorrect ||
    _LearningSurface.lessonComplete => _lesson(true),
    _LearningSurface.lessonFeedbackIncorrect => _lesson(false),
    _LearningSurface.questionReady ||
    _LearningSurface.questionFeedbackCorrect ||
    _LearningSurface.questionFeedbackIncorrect ||
    _LearningSurface.questionComplete => _questions(_QuestionRepository()),
    _LearningSurface.questionEmpty => _questions(
      _QuestionRepository(items: const [], totalDue: 0),
    ),
    _LearningSurface.questionError => _questions(
      _QuestionRepository(
        error: const ApiException(
          code: 'network_unavailable',
          message: 'offline',
        ),
      ),
    ),
    _LearningSurface.vocabularyReady ||
    _LearningSurface.vocabularyBack ||
    _LearningSurface.vocabularyComplete => _vocabulary(
      _ReviewRepository(
        cards: [
          ReviewCard(
            id: 'golden-card',
            front: 'Apple',
            back: 'Quả táo',
            due: DateTime.utc(2025, 1, 1),
            state: 'new',
            reps: 0,
          ),
        ],
      ),
    ),
    _LearningSurface.vocabularyEmpty => _vocabulary(_ReviewRepository()),
    _LearningSurface.vocabularyError => _vocabulary(
      _ReviewRepository(
        error: const ApiException(
          code: 'network_unavailable',
          message: 'offline',
        ),
      ),
    ),
  };

  await pumpLingoRoadGoldenSurface(
    tester,
    child: child,
    themeMode: mode,
    size: size,
    textScaleFactor: textScaleFactor,
  );

  switch (surface) {
    case _LearningSurface.lessonFeedbackCorrect:
    case _LearningSurface.lessonComplete:
      await tester.tap(find.byKey(const Key('lesson_option_studies')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lesson_submit')));
      await tester.pumpAndSettle();
      if (surface == _LearningSurface.lessonComplete) {
        await tester.tap(find.byKey(const Key('lesson_next')));
        await tester.pumpAndSettle();
      }
    case _LearningSurface.lessonFeedbackIncorrect:
      await tester.tap(find.byKey(const Key('lesson_option_study')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lesson_submit')));
      await tester.pumpAndSettle();
    case _LearningSurface.questionFeedbackCorrect:
      await tester.tap(find.byKey(const Key('answer_option_blue')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('question_review_check')));
      await tester.pumpAndSettle();
    case _LearningSurface.questionFeedbackIncorrect:
    case _LearningSurface.questionComplete:
      await tester.tap(find.byKey(const Key('answer_option_red')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('question_review_check')));
      await tester.pumpAndSettle();
      if (surface == _LearningSurface.questionComplete) {
        await tester.tap(find.byKey(const Key('question_review_next')));
        await tester.pumpAndSettle();
      }
    case _LearningSurface.vocabularyComplete:
      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review_mark_learned_button')));
      await tester.pumpAndSettle();
    case _LearningSurface.vocabularyBack:
      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();
    default:
      break;
  }
}

void main() {
  setUpAll(loadLingoRoadGoldenFonts);

  final canCompareGolden = Platform.isLinux || _allowWindowsGoldenUpdate;
  for (final surface in _LearningSurface.values) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final suffix = mode == ThemeMode.light ? 'light' : 'dark';
      testWidgets('${surface.goldenName} $suffix golden', (tester) async {
        await _pumpSurface(tester, surface, mode);
        await expectLater(
          find.byKey(lingoRoadGoldenRootKey),
          matchesGoldenFile('learning/${surface.goldenName}_$suffix.png'),
        );
      }, skip: !canCompareGolden);
    }
  }

  const profiles = [
    (name: 'compact-320', size: Size(320, 844), textScale: 1.0),
    (name: 'standard-390', size: Size(390, 844), textScale: 1.0),
    (name: 'wide-600', size: Size(600, 844), textScale: 1.0),
    (name: 'text-scale-1.3', size: Size(390, 844), textScale: 1.3),
  ];
  for (final profile in profiles) {
    testWidgets(
      'major learning surfaces render without overflow at ${profile.name}',
      (tester) async {
        for (final surface in const [
          _LearningSurface.home,
          _LearningSurface.pathLoaded,
          _LearningSurface.lessonFeedbackIncorrect,
          _LearningSurface.questionFeedbackIncorrect,
          _LearningSurface.vocabularyReady,
        ]) {
          await _pumpSurface(
            tester,
            surface,
            ThemeMode.light,
            size: profile.size,
            textScaleFactor: profile.textScale,
          );
          expect(tester.takeException(), isNull, reason: surface.goldenName);
        }
      },
    );
  }
}
