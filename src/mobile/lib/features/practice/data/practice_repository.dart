import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/practice/domain/practice_models.dart';

abstract interface class AiPracticeRepository {
  Future<String> askAdvisor(String question);
  Future<WritingResult> evaluateWriting(String taskPrompt, String essay);
  Future<SpeakingScore> scoreSpeaking(String prompt, RecordedAudio audio);
  Future<List<SpeakingHistoryItem>> speakingHistory();
}

class ApiAiPracticeRepository implements AiPracticeRepository {
  const ApiAiPracticeRepository(this._api);

  final ApiClient _api;

  @override
  Future<String> askAdvisor(String question) async {
    final body = _map(await _api.postJson('/path/advisor',
        body: {'question': question}, timeout: const Duration(seconds: 45)));
    return body['answer']?.toString() ??
        (throw const ApiException(
          code: 'malformed_response',
          message: 'Phản hồi máy chủ không hợp lệ',
        ));
  }

  @override
  Future<WritingResult> evaluateWriting(String taskPrompt, String essay) async {
    final body = _map(await _api.postJson('/writing/evaluate',
        body: {'taskPrompt': taskPrompt, 'essay': essay},
        timeout: const Duration(seconds: 45)));
    final scores = _map(body['scores']);
    final feedback = (body['feedback'] as List<dynamic>? ?? const [])
        .map((item) => _map(item))
        .map((item) => WritingFeedback(
              sentence: item['sentence']?.toString() ?? '',
              issue: item['issue']?.toString() ?? '',
              suggestion: item['suggestion']?.toString() ?? '',
            ))
        .toList(growable: false);
    return WritingResult(
      scores: WritingScores(
        taskAchievement: _number(scores['taskAchievement']),
        coherenceCohesion: _number(scores['coherenceCohesion']),
        lexicalResource: _number(scores['lexicalResource']),
        grammaticalAccuracy: _number(scores['grammaticalAccuracy']),
      ),
      feedback: feedback,
      overallVi: body['overallVi']?.toString() ?? '',
    );
  }

  @override
  Future<SpeakingScore> scoreSpeaking(
      String prompt, RecordedAudio audio) async {
    final body = _map(await _api.postMultipart(
      '/speaking/attempts',
      fields: {'promptText': prompt},
      fileField: 'audio',
      fileBytes: audio.bytes,
      fileName: audio.fileName,
      mimeType: audio.mimeType,
      timeout: const Duration(seconds: 90),
    ));
    return SpeakingScore(
      transcript: body['transcript']?.toString() ?? '',
      accuracy: _number(body['accuracy']),
      completeness: _number(body['completeness']),
      fluency: _number(body['fluency']),
      total: _number(body['total']),
      durationSeconds: _number(body['durationSeconds']),
      modelVersion: body['modelVersion']?.toString() ?? 'unknown',
      feedbackVi: body['feedbackVi']?.toString() ?? '',
    );
  }

  @override
  Future<List<SpeakingHistoryItem>> speakingHistory() async {
    final body = await _api.get('/speaking/attempts');
    if (body is! List<dynamic>) {
      throw const ApiException(
        code: 'malformed_response',
        message: 'Phản hồi máy chủ không hợp lệ',
      );
    }
    return body
        .map((item) => _map(item))
        .map((item) => SpeakingHistoryItem(
              id: item['id'].toString(),
              promptText: item['promptText']?.toString() ?? '',
              transcript: item['transcript']?.toString(),
              total: _number(item['total']),
              modelVersion: item['modelVersion']?.toString() ?? 'unknown',
              createdAt:
                  DateTime.tryParse(item['createdAt']?.toString() ?? '') ??
                      DateTime.fromMillisecondsSinceEpoch(0),
            ))
        .toList(growable: false);
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const ApiException(
      code: 'malformed_response',
      message: 'Phản hồi máy chủ không hợp lệ',
    );
  }

  static double _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}
