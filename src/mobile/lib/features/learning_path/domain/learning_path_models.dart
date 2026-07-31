import 'package:lingoroad_mobile/core/network/api_exception.dart';

class LearningPathStep {
  const LearningPathStep({
    required this.code,
    required this.name,
    required this.nameVi,
    required this.cefr,
    required this.mastery,
    required this.reason,
  });

  final String code;
  final String name;
  final String nameVi;
  final String cefr;
  final double mastery;
  final String reason;

  factory LearningPathStep.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw _malformed();
    }

    final code = _requiredString(value, 'code');
    final name = _requiredString(value, 'name');
    final nameVi = _requiredString(value, 'nameVi');
    final cefr = _requiredString(value, 'cefr');
    final mastery = _double(value['mastery']);
    final reason = _requiredString(value, 'reason');

    if (!const {'A1', 'A2', 'B1', 'B2'}.contains(cefr) ||
        mastery == null ||
        mastery < 0 ||
        mastery > 1) {
      throw _malformed();
    }

    return LearningPathStep(
      code: code,
      name: name,
      nameVi: nameVi,
      cefr: cefr,
      mastery: mastery,
      reason: reason,
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw _malformed();
  }
  return value;
}

double? _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

ApiException _malformed() => const ApiException(
      code: 'malformed_response',
      message: 'Phản hồi lộ trình học không hợp lệ',
    );
