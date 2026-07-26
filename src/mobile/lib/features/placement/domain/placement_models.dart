import 'package:lingoroad_mobile/core/network/api_exception.dart';

class PlacementItem {
  const PlacementItem({
    required this.id,
    required this.type,
    required this.stem,
    required this.options,
    this.audioUrl,
  });

  final String id;
  final String type;
  final String stem;
  final List<String> options;
  final String? audioUrl;

  factory PlacementItem.fromJson(Object? value) {
    final json = _jsonMap(value);
    final id = _requiredString(json, 'id');
    final type = _requiredString(json, 'type');
    final stem = _requiredString(json, 'stem');
    final rawOptions = json['options'];
    if (rawOptions is! List || rawOptions.isEmpty) {
      throw _malformed();
    }
    final options = rawOptions
        .map((option) => option?.toString().trim() ?? '')
        .toList(growable: false);
    if (options.any((option) => option.isEmpty)) {
      throw _malformed();
    }

    final audioUrl = json['audioUrl']?.toString().trim();
    return PlacementItem(
      id: id,
      type: type,
      stem: stem,
      options: options,
      audioUrl: audioUrl == null || audioUrl.isEmpty ? null : audioUrl,
    );
  }
}

class PlacementStart {
  const PlacementStart({
    required this.sessionId,
    required this.item,
  });

  final String sessionId;
  final PlacementItem item;

  factory PlacementStart.fromJson(Object? value) {
    final json = _jsonMap(value);
    return PlacementStart(
      sessionId: _requiredString(json, 'sessionId'),
      item: PlacementItem.fromJson(json['item']),
    );
  }
}

class PlacementStep {
  const PlacementStep({
    required this.done,
    this.item,
    this.theta,
    this.se,
    this.cefr,
  });

  final bool done;
  final PlacementItem? item;
  final double? theta;
  final double? se;
  final String? cefr;

  factory PlacementStep.fromJson(Object? value) {
    final json = _jsonMap(value);
    final done = json['done'];
    if (done is! bool) {
      throw _malformed();
    }

    final item =
        json['item'] == null ? null : PlacementItem.fromJson(json['item']);
    final theta = _optionalDouble(json['theta']);
    final se = _optionalDouble(json['se']);
    final cefr = json['cefr']?.toString().trim();
    if ((!done && item == null) ||
        (done &&
            (theta == null || se == null || cefr == null || cefr.isEmpty))) {
      throw _malformed();
    }

    return PlacementStep(
      done: done,
      item: item,
      theta: theta,
      se: se,
      cefr: cefr,
    );
  }
}

class PlacementResult {
  const PlacementResult({
    required this.theta,
    required this.se,
    required this.cefr,
    required this.itemsAnswered,
    required this.status,
  });

  final double theta;
  final double se;
  final String cefr;
  final int itemsAnswered;
  final String status;

  factory PlacementResult.fromJson(Object? value) {
    final json = _jsonMap(value);
    final theta = _optionalDouble(json['theta']);
    final se = _optionalDouble(json['se']);
    final cefr = json['cefr']?.toString().trim();
    final itemsAnswered = _optionalInt(json['itemsAnswered']);
    final status = json['status']?.toString().trim();
    if (theta == null ||
        se == null ||
        cefr == null ||
        cefr.isEmpty ||
        itemsAnswered == null ||
        itemsAnswered < 0 ||
        status == null ||
        status.isEmpty) {
      throw _malformed();
    }
    return PlacementResult(
      theta: theta,
      se: se,
      cefr: cefr,
      itemsAnswered: itemsAnswered,
      status: status,
    );
  }
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw _malformed();
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    throw _malformed();
  }
  return value;
}

double? _optionalDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

int? _optionalInt(Object? value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '');

ApiException _malformed() => const ApiException(
      code: 'malformed_response',
      message: 'Phản hồi placement không hợp lệ',
    );
