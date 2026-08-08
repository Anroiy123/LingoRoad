import 'package:lingoroad_mobile/core/network/api_exception.dart';

class TodayLesson {
  const TodayLesson({
    required this.id,
    required this.slug,
    required this.title,
    required this.titleVi,
    required this.skillCode,
    required this.cefr,
    required this.itemCount,
    this.completed = false,
    this.mastery = 0,
  });

  final String id;
  final String slug;
  final String title;
  final String titleVi;
  final String skillCode;
  final String cefr;
  final int itemCount;
  final bool completed;
  final double mastery;

  factory TodayLesson.fromJson(Object? value) {
    final json = _map(value);
    return TodayLesson(
      id: _text(json, 'id'),
      slug: _text(json, 'slug'),
      title: _text(json, 'title'),
      titleVi: _text(json, 'titleVi'),
      skillCode: _text(json, 'skillCode'),
      cefr: _text(json, 'cefr'),
      itemCount: _integer(json, 'itemCount'),
      completed: json['completed'] == true,
      mastery: _number(json['mastery']) ?? 0,
    );
  }
}

class LessonExercise {
  const LessonExercise({
    required this.id,
    required this.sequence,
    required this.type,
    required this.stem,
    required this.options,
    required this.answered,
  });

  final String id;
  final int sequence;
  final String type;
  final String stem;
  final List<String> options;
  final bool answered;

  factory LessonExercise.fromJson(Object? value) {
    final json = _map(value);
    final rawOptions = json['options'];
    if (rawOptions is! List) throw _malformed();
    return LessonExercise(
      id: _text(json, 'id'),
      sequence: _integer(json, 'sequence'),
      type: _text(json, 'type'),
      stem: _text(json, 'stem'),
      options:
          rawOptions.map((item) => item.toString()).toList(growable: false),
      answered: json['answered'] == true,
    );
  }
}

class LessonAttempt {
  const LessonAttempt({
    required this.id,
    required this.lessonId,
    required this.slug,
    required this.title,
    required this.titleVi,
    required this.skillCode,
    required this.status,
    required this.exercises,
  });

  final String id;
  final String lessonId;
  final String slug;
  final String title;
  final String titleVi;
  final String skillCode;
  final String status;
  final List<LessonExercise> exercises;

  factory LessonAttempt.fromJson(Object? value) {
    final json = _map(value);
    final rawExercises = json['exercises'];
    if (rawExercises is! List) throw _malformed();
    return LessonAttempt(
      id: _text(json, 'id'),
      lessonId: _text(json, 'lessonId'),
      slug: _text(json, 'slug'),
      title: _text(json, 'title'),
      titleVi: _text(json, 'titleVi'),
      skillCode: json['skillCode']?.toString() ?? '',
      status: _text(json, 'status'),
      exercises:
          rawExercises.map(LessonExercise.fromJson).toList(growable: false),
    );
  }
}

class ExerciseFeedback {
  const ExerciseFeedback({
    required this.correct,
    required this.correctAnswer,
    this.explanationVi,
  });

  final bool correct;
  final String correctAnswer;
  final String? explanationVi;

  factory ExerciseFeedback.fromJson(Object? value) {
    final json = _map(value);
    if (json['correct'] is! bool) throw _malformed();
    return ExerciseFeedback(
      correct: json['correct'] as bool,
      correctAnswer: _text(json, 'correctAnswer'),
      explanationVi: json['explanationVi']?.toString(),
    );
  }
}

class LessonCompletion {
  const LessonCompletion({
    required this.correctAnswers,
    required this.totalAnswers,
    required this.reviewCardsCreated,
  });

  final int correctAnswers;
  final int totalAnswers;
  final int reviewCardsCreated;

  factory LessonCompletion.fromJson(Object? value) {
    final json = _map(value);
    return LessonCompletion(
      correctAnswers: _integer(json, 'correctAnswers'),
      totalAnswers: _integer(json, 'totalAnswers'),
      reviewCardsCreated: _integer(json, 'reviewCardsCreated'),
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) throw _malformed();
  return value;
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) throw _malformed();
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) throw _malformed();
  return parsed;
}

double? _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

ApiException _malformed() => const ApiException(
      code: 'malformed_response',
      message: 'Phản hồi bài học không hợp lệ',
    );

class MistakeRecord {
  const MistakeRecord({
    required this.exercise,
    required this.userAnswer,
    required this.feedback,
  });

  final LessonExercise exercise;
  final String userAnswer;
  final ExerciseFeedback feedback;
}
