import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/dictionary/data/dictionary_repository.dart';
import 'package:lingoroad_mobile/features/dictionary/data/saved_word_repository.dart';
import 'package:lingoroad_mobile/features/lesson/data/lesson_repository.dart';
import 'package:lingoroad_mobile/features/lesson/domain/lesson_models.dart';
import 'package:lingoroad_mobile/features/lesson/presentation/lesson_screen.dart';
import 'package:lingoroad_mobile/features/lesson/presentation/lesson_view_model.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../helpers/widget_test_harness.dart';

const exercise = LessonExercise(
  id: 'exercise-1',
  sequence: 1,
  type: 'mcq',
  stem: 'Lan ___ English every day.',
  options: ['study', 'studies'],
  answered: false,
);

const attempt = LessonAttempt(
  id: 'attempt-1',
  lessonId: 'lesson-1',
  slug: 'present-simple',
  title: 'Present Simple',
  titleVi: 'Hiện tại đơn',
  skillCode: 'grammar.present-simple',
  status: 'in_progress',
  exercises: [exercise],
);

const reorderExercise = LessonExercise(
  id: 'exercise-reorder',
  sequence: 1,
  type: 'reorder',
  stem: 'Arrange the sentence.',
  options: ['I', 'learn', 'English'],
  answered: false,
);

const reorderAttempt = LessonAttempt(
  id: 'attempt-reorder',
  lessonId: 'lesson-reorder',
  slug: 'reorder',
  title: 'Reorder',
  titleVi: 'Sắp xếp câu',
  skillCode: 'grammar.word-order',
  status: 'in_progress',
  exercises: [reorderExercise],
);

class FakeLessonRepository implements LessonRepository {
  Object? startError;
  bool failSubmitOnce = false;
  Completer<ExerciseFeedback>? submitCompleter;
  int startCalls = 0;
  int submitCalls = 0;
  int completeCalls = 0;
  final operationIds = <String>[];
  final answers = <String>[];

  @override
  Future<List<TodayLesson>> today() async => const [];

  @override
  Future<LessonAttempt> start(String lessonId, String operationId) async {
    startCalls++;
    if (startError != null) throw startError!;
    return attempt;
  }

  @override
  Future<LessonAttempt> getAttempt(String attemptId) async => attempt;

  @override
  Future<ExerciseFeedback> submit({
    required String exerciseId,
    required String answer,
    required String operationId,
  }) async {
    submitCalls++;
    operationIds.add(operationId);
    answers.add(answer);
    if (failSubmitOnce) {
      failSubmitOnce = false;
      throw const ApiException(code: 'network_unavailable', message: 'offline');
    }
    if (submitCompleter != null) return submitCompleter!.future;
    return const ExerciseFeedback(correct: true, correctAnswer: 'studies');
  }

  @override
  Future<LessonCompletion> complete(
    String attemptId,
    String operationId,
  ) async {
    completeCalls++;
    return const LessonCompletion(
      correctAnswers: 1,
      totalAnswers: 1,
      reviewCardsCreated: 0,
    );
  }
}

class ReorderLessonRepository extends FakeLessonRepository {
  @override
  Future<LessonAttempt> start(String lessonId, String operationId) async =>
      reorderAttempt;

  @override
  Future<LessonAttempt> getAttempt(String attemptId) async => reorderAttempt;

  @override
  Future<ExerciseFeedback> submit({
    required String exerciseId,
    required String answer,
    required String operationId,
  }) async => ExerciseFeedback(
    correct: answer == 'I learn English',
    correctAnswer: 'I  learn English',
  );
}

class FakeDictionaryRepository implements DictionaryRepository {
  String? nextDefinition;
  Object? lookupError;
  final lookedUpWords = <String>[];

  @override
  Future<String> lookup(String word) async {
    lookedUpWords.add(word);
    if (lookupError != null) throw lookupError!;
    return nextDefinition ?? 'định nghĩa mẫu';
  }
}

class FakeSavedWordRepository implements SavedWordRepository {
  Object? saveError;
  int saveCalls = 0;
  String? lastSkillCode;
  String? lastWord;
  String? lastDefinition;

  @override
  Future<void> save(String skillCode, String word, String definition) async {
    saveCalls++;
    lastSkillCode = skillCode;
    lastWord = word;
    lastDefinition = definition;
    if (saveError != null) throw saveError!;
  }
}

AppLanguageProvider languageProvider() {
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

Widget lessonApp(
  LessonRepository repository, {
  DictionaryRepository? dictionaryRepository,
  SavedWordRepository? savedWordRepository,
  ThemeData? theme,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppLanguageProvider>.value(
      value: languageProvider(),
    ),
    ChangeNotifierProvider<LessonViewModel>(
      create: (_) => LessonViewModel(repository),
    ),
    Provider<DictionaryRepository>.value(
      value: dictionaryRepository ?? FakeDictionaryRepository(),
    ),
    Provider<SavedWordRepository>.value(
      value: savedWordRepository ?? FakeSavedWordRepository(),
    ),
  ],
  child: MaterialApp(
    theme: theme ?? AppTheme.light,
    home: const LessonScreen(lessonId: 'lesson-1'),
  ),
);

void main() {
  test('double submit gửi một request và retry giữ operation ID', () async {
    final repository = FakeLessonRepository();
    final viewModel = LessonViewModel(repository);
    await viewModel.load('lesson-1');
    repository.submitCompleter = Completer<ExerciseFeedback>();

    final first = viewModel.submit('studies');
    await viewModel.submit('studies');
    expect(repository.submitCalls, 1);
    repository.submitCompleter!.complete(
      const ExerciseFeedback(correct: true, correctAnswer: 'studies'),
    );
    await first;

    final retryRepository = FakeLessonRepository()..failSubmitOnce = true;
    final retryViewModel = LessonViewModel(retryRepository);
    await retryViewModel.load('lesson-1');
    await retryViewModel.submit('studies');
    expect(retryViewModel.errorCode, 'network_unavailable');
    await retryViewModel.retryAnswer();
    expect(retryRepository.operationIds.length, 2);
    expect(retryRepository.operationIds[0], retryRepository.operationIds[1]);
  });

  testWidgets(
    'lỗi submit khóa đáp án và Retry gửi lại đúng payload cùng operation ID',
    (tester) async {
      final repository = FakeLessonRepository()..failSubmitOnce = true;
      await pumpWidgetWithLingoRoadScreenUtil(tester, lessonApp(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lesson_option_study')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lesson_submission_error')), findsOneWidget);
      expect(find.text('study'), findsOneWidget);
      expect(find.byKey(const Key('lesson_option_studies')), findsNothing);
      final firstOperationId = repository.operationIds.single;

      await tester.tap(find.byKey(const Key('lesson_retry_answer')));
      await tester.pumpAndSettle();

      expect(repository.answers, ['study', 'study']);
      expect(repository.operationIds, [firstOperationId, firstOperationId]);
      expect(find.byKey(const Key('lesson_feedback')), findsOneWidget);
    },
  );

  testWidgets(
    'Đổi đáp án bỏ pending retry và gửi đáp án mới với operation ID mới',
    (tester) async {
      final repository = FakeLessonRepository()..failSubmitOnce = true;
      await pumpWidgetWithLingoRoadScreenUtil(tester, lessonApp(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lesson_option_study')));
      await tester.pumpAndSettle();
      final firstOperationId = repository.operationIds.single;

      await tester.tap(find.byKey(const Key('lesson_change_answer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lesson_option_studies')));
      await tester.pumpAndSettle();

      expect(repository.answers, ['study', 'studies']);
      expect(repository.operationIds.last, isNot(firstOperationId));
      expect(find.byKey(const Key('lesson_feedback')), findsOneWidget);
    },
  );

  testWidgets('hiển thị feedback rồi complete lesson', (tester) async {
    final repository = FakeLessonRepository();
    await pumpWidgetWithLingoRoadScreenUtil(tester, lessonApp(repository));
    await tester.pumpAndSettle();

    expectRenderedTextSequence(
      find.byKey(const Key('lesson_stem')),
      'Lan ___ English every day.',
    );
    await tester.tap(find.byKey(const Key('lesson_option_studies')));
    await tester.pumpAndSettle();
    expect(find.text('Chính xác!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lesson_next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lesson_completed')), findsOneWidget);
    expect(find.text('Bạn đã hoàn thành bài học hôm nay.'), findsOneWidget);
    expect(find.text('lesson.complete.subtitle'), findsNothing);
    expect(repository.completeCalls, 1);
  });

  testWidgets('load lỗi có retry', (tester) async {
    final repository = FakeLessonRepository()
      ..startError = const ApiException(
        code: 'network_unavailable',
        message: 'offline',
      );
    await pumpWidgetWithLingoRoadScreenUtil(tester, lessonApp(repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lesson_error')), findsOneWidget);

    repository.startError = null;
    await tester.tap(find.byKey(const Key('lesson_retry')));
    await tester.pumpAndSettle();
    expectRenderedTextSequence(
      find.byKey(const Key('lesson_stem')),
      'Lan ___ English every day.',
    );
  });

  testWidgets('giữ tay vào từ để tra nghĩa rồi lưu từ vào danh sách xem lại', (
    tester,
  ) async {
    final repository = FakeLessonRepository();
    final dictionaryRepository = FakeDictionaryRepository()
      ..nextDefinition = 'một cái tên tiếng Việt';
    final savedWordRepository = FakeSavedWordRepository();
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      lessonApp(
        repository,
        dictionaryRepository: dictionaryRepository,
        savedWordRepository: savedWordRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Lan'));
    await tester.pumpAndSettle();

    expect(dictionaryRepository.lookedUpWords, ['Lan']);
    expect(find.byKey(const Key('dictionary_definition')), findsOneWidget);
    expect(find.text('một cái tên tiếng Việt'), findsOneWidget);
    expect(find.byKey(const Key('dictionary_save_word')), findsOneWidget);
    expect(find.byKey(const Key('dictionary_word_saved')), findsNothing);

    await tester.tap(find.byKey(const Key('dictionary_save_word')));
    await tester.pumpAndSettle();

    expect(savedWordRepository.saveCalls, 1);
    expect(savedWordRepository.lastSkillCode, 'grammar.present-simple');
    expect(savedWordRepository.lastWord, 'Lan');
    expect(savedWordRepository.lastDefinition, 'một cái tên tiếng Việt');
    expect(find.byKey(const Key('dictionary_word_saved')), findsOneWidget);
    expect(find.byKey(const Key('dictionary_save_word')), findsNothing);
  });

  testWidgets('lỗi tra từ điển hiển thị thông báo lỗi, không có nút lưu', (
    tester,
  ) async {
    final repository = FakeLessonRepository();
    final dictionaryRepository = FakeDictionaryRepository()
      ..lookupError = const ApiException(
        code: 'network_unavailable',
        message: 'offline',
      );
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      lessonApp(repository, dictionaryRepository: dictionaryRepository),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('English'));
    await tester.pumpAndSettle();

    expect(dictionaryRepository.lookedUpWords, ['English']);
    expect(find.text('Dữ liệu được giữ an toàn. Hãy thử lại.'), findsOneWidget);
    expect(find.byKey(const Key('dictionary_definition')), findsNothing);
    expect(find.byKey(const Key('dictionary_save_word')), findsNothing);
  });

  testWidgets('nút từ điển hiển thị rõ ràng và cho chọn từ để tra', (
    tester,
  ) async {
    final dictionaryRepository = FakeDictionaryRepository()
      ..nextDefinition = 'học';
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      lessonApp(
        FakeLessonRepository(),
        dictionaryRepository: dictionaryRepository,
      ),
    );
    await tester.pumpAndSettle();

    final dictionaryButton = find.byKey(const Key('lesson_dictionary_button'));
    expect(dictionaryButton, findsOneWidget);
    expect(tester.getSize(dictionaryButton).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(dictionaryButton).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(dictionaryButton).label,
      contains('Tra từ trong câu'),
    );

    await tester.tap(dictionaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lesson_dictionary_word_English')));
    await tester.pumpAndSettle();

    expect(dictionaryRepository.lookedUpWords, ['English']);
    expect(find.byKey(const Key('dictionary_definition')), findsOneWidget);
  });

  testWidgets(
    'feedback giữ lựa chọn, công bố đúng/sai bằng semantics live region và nhận focus',
    (tester) async {
      await pumpWidgetWithLingoRoadScreenUtil(
        tester,
        lessonApp(FakeLessonRepository()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lesson_option_studies')));
      await tester.pumpAndSettle();

      final selected = tester.getSemantics(
        find.byKey(const Key('lesson_option_studies')),
      );
      expect(selected.flagsCollection.isSelected, Tristate.isTrue);
      expect(selected.label, contains('đúng'));

      final feedbackFinder = find.byKey(const Key('lesson_feedback'));
      final feedback = tester.widget<Semantics>(feedbackFinder);
      expect(feedback.properties.liveRegion, isTrue);
      final focus = tester.widget<Focus>(
        find.descendant(of: feedbackFinder, matching: find.byType(Focus)).first,
      );
      expect(focus.focusNode?.hasFocus, isTrue);
    },
  );

  testWidgets('reorder feedback lesson công bố đúng và tô trạng thái đúng', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      lessonApp(ReorderLessonRepository()),
    );
    await tester.pumpAndSettle();

    for (final index in [0, 1, 2]) {
      await tester.tap(find.byKey(Key('answer_reorder_$index')));
    }
    await tester.pump();
    await tester.tap(find.byKey(const Key('lesson_submit')));
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
  });

  testWidgets('reorder feedback lesson công bố sai và tô trạng thái sai', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      lessonApp(ReorderLessonRepository()),
    );
    await tester.pumpAndSettle();

    for (final index in [1, 0, 2]) {
      await tester.tap(find.byKey(Key('answer_reorder_$index')));
    }
    await tester.pump();
    await tester.tap(find.byKey(const Key('lesson_submit')));
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
  });

  testWidgets('feedback reorder dark dùng màu semantic của ColorScheme', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      lessonApp(ReorderLessonRepository(), theme: AppTheme.dark),
    );
    await tester.pumpAndSettle();

    for (final index in [0, 1, 2]) {
      await tester.tap(find.byKey(Key('answer_reorder_$index')));
    }
    await tester.pump();
    await tester.tap(find.byKey(const Key('lesson_submit')));
    await tester.pumpAndSettle();

    final feedback = tester.widget<Container>(
      find.byKey(const Key('answer_reorder_feedback_visual')),
    );
    final decoration = feedback.decoration! as BoxDecoration;
    expect(decoration.color, AppTheme.dark.colorScheme.primaryContainer);
    expect(
      decoration.border,
      Border.all(color: AppTheme.dark.colorScheme.primary, width: 1.5),
    );
  });
}
