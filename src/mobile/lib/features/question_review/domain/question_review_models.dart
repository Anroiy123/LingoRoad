import 'package:lingoroad_mobile/core/network/api_exception.dart';

class QuestionReviewItem {
  const QuestionReviewItem({
    required this.id,
    required this.reps,
    required this.type,
    required this.stem,
    required this.options,
  });

  final String id;
  final int reps;
  final String type;
  final String stem;
  final List<String> options;

  factory QuestionReviewItem.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['reps'] is! int ||
        value['type'] is! String ||
        value['stem'] is! String ||
        value['options'] is! List) {
      throw _malformed();
    }
    final options = (value['options'] as List).cast<Object?>();
    if (value['reps'] < 0 ||
        !const {'mcq', 'cloze', 'reorder'}.contains(value['type']) ||
        options.any((option) => option is! String)) {
      throw _malformed();
    }
    return QuestionReviewItem(
      id: value['id'] as String,
      reps: value['reps'] as int,
      type: value['type'] as String,
      stem: value['stem'] as String,
      options: options.cast<String>(),
    );
  }
}

class QuestionReviewSession {
  const QuestionReviewSession({required this.items, required this.totalDue});

  final List<QuestionReviewItem> items;
  final int totalDue;

  factory QuestionReviewSession.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['totalDue'] is! int ||
        value['items'] is! List ||
        value['totalDue'] < 0) {
      throw _malformed();
    }
    return QuestionReviewSession(
      totalDue: value['totalDue'] as int,
      items: (value['items'] as List)
          .map(QuestionReviewItem.fromJson)
          .toList(growable: false),
    );
  }
}

class QuestionReviewCheck {
  const QuestionReviewCheck({
    required this.correct,
    required this.correctAnswer,
    this.explanationVi,
  });

  final bool correct;
  final String correctAnswer;
  final String? explanationVi;

  factory QuestionReviewCheck.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['correct'] is! bool ||
        value['correctAnswer'] is! String ||
        (value['explanationVi'] != null && value['explanationVi'] is! String)) {
      throw _malformed();
    }
    return QuestionReviewCheck(
      correct: value['correct'] as bool,
      correctAnswer: value['correctAnswer'] as String,
      explanationVi: value['explanationVi'] as String?,
    );
  }
}

class QuestionReviewGrade {
  const QuestionReviewGrade({required this.xp, required this.coins});

  final int xp;
  final int coins;

  factory QuestionReviewGrade.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['xp'] is! int ||
        value['coins'] is! int) {
      throw _malformed();
    }
    return QuestionReviewGrade(xp: value['xp'] as int, coins: value['coins'] as int);
  }
}

ApiException _malformed() => const ApiException(
      code: 'malformed_response',
      message: 'Phản hồi ôn tập câu hỏi không hợp lệ',
    );
