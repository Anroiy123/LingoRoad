import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

class FakeLessonRepository implements LessonRepository {
  Object? startError;
  bool failSubmitOnce = false;
  Completer<ExerciseFeedback>? submitCompleter;
  int startCalls = 0;
  int submitCalls = 0;
  int completeCalls = 0;
  final operationIds = <String>[];

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
    if (failSubmitOnce) {
      failSubmitOnce = false;
      throw const ApiException(code: 'network_unavailable', message: 'offline');
    }
    if (submitCompleter != null) return submitCompleter!.future;
    return const ExerciseFeedback(correct: true, correctAnswer: 'studies');
  }

  @override
  Future<LessonCompletion> complete(
      String attemptId, String operationId) async {
    completeCalls++;
    return const LessonCompletion(
      correctAnswers: 1,
      totalAnswers: 1,
      reviewCardsCreated: 0,
    );
  }
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
  final vi = json.decode(File('assets/translations/vi.json').readAsStringSync())
      as Map<String, dynamic>;
  final en = json.decode(File('assets/translations/en.json').readAsStringSync())
      as Map<String, dynamic>;
  return AppLanguageProvider.test(
    translations: {AppLanguage.vi: vi, AppLanguage.en: en},
  );
}

Widget lessonApp(
  FakeLessonRepository repository, {
  DictionaryRepository? dictionaryRepository,
  SavedWordRepository? savedWordRepository,
}) =>
    MultiProvider(
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
        theme: AppTheme.light,
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

  testWidgets('giữ tay vào từ để tra nghĩa rồi lưu từ vào danh sách xem lại',
      (tester) async {
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

  testWidgets('lỗi tra từ điển hiển thị thông báo lỗi, không có nút lưu',
      (tester) async {
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
    expect(find.text('Dữ liệu được giữ an toàn. Hãy thử lại.'),
        findsOneWidget);
    expect(find.byKey(const Key('dictionary_definition')), findsNothing);
    expect(find.byKey(const Key('dictionary_save_word')), findsNothing);
  });
}
