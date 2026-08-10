import 'package:lingoroad_mobile/core/network/api_exception.dart';

class ReviewCard {
  const ReviewCard(
      {required this.id,
      required this.front,
      required this.back,
      required this.due,
      required this.state,
      required this.reps});
  final String id;
  final String front;
  final String back;
  final DateTime due;
  final String state;
  final int reps;

  factory ReviewCard.fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['id'] is! String) {
      throw _malformed();
    }
    final id = value['id'] as String;
    final front = (value['front'] ?? value['word']) as String?;
    final back = (value['back'] ?? value['definition']) as String?;
    final dueStr = (value['due'] ?? value['nextReviewAt']) as String?;
    final state = (value['state'] ?? 'new') as String;
    final reps = (value['reps'] ?? value['reviewStage'] ?? 0) as int;

    if (front == null || back == null || reps < 0) throw _malformed();
    final due = dueStr != null ? DateTime.tryParse(dueStr) : DateTime.now();
    if (due == null) throw _malformed();

    return ReviewCard(
      id: id,
      front: front,
      back: back,
      due: due,
      state: state,
      reps: reps,
    );
  }
}

ApiException _malformed() => const ApiException(
    code: 'malformed_response', message: 'Phản hồi ôn tập không hợp lệ');
