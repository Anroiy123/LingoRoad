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
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['front'] is! String ||
        value['back'] is! String ||
        value['state'] is! String ||
        value['reps'] is! int) {
      throw _malformed();
    }
    final due = DateTime.tryParse(value['due'] as String);
    if (due == null || (value['reps'] as int) < 0) throw _malformed();
    return ReviewCard(
        id: value['id'] as String,
        front: value['front'] as String,
        back: value['back'] as String,
        due: due,
        state: value['state'] as String,
        reps: value['reps'] as int);
  }
}

ApiException _malformed() => const ApiException(
    code: 'malformed_response', message: 'Phản hồi ôn tập không hợp lệ');
