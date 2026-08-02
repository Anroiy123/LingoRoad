import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/practice/data/practice_repository.dart';
import 'package:lingoroad_mobile/features/practice/data/speaking_recorder.dart';
import 'package:lingoroad_mobile/features/practice/domain/practice_models.dart';

enum PracticeStatus { idle, loading, success, error }

class AiPracticeViewModel extends ChangeNotifier {
  AiPracticeViewModel(this._repository, this._recorder);

  final AiPracticeRepository _repository;
  final SpeakingRecorder _recorder;
  PracticeStatus advisorStatus = PracticeStatus.idle;
  PracticeStatus writingStatus = PracticeStatus.idle;
  PracticeStatus speakingStatus = PracticeStatus.idle;
  PracticeStatus historyStatus = PracticeStatus.idle;
  String? advisorAnswer;
  WritingResult? writingResult;
  SpeakingScore? speakingScore;
  List<SpeakingHistoryItem> history = const [];
  String? advisorError;
  String? writingError;
  String? speakingError;
  String? historyError;
  bool recording = false;
  int recordingSeconds = 0;
  String? _lastQuestion;
  String? _lastTask;
  String? _lastEssay;
  String? _speakingPrompt;
  RecordedAudio? _pendingAudio;
  Timer? _recordingTimer;
  bool _disposed = false;

  bool get canRetrySpeaking => _pendingAudio != null;

  Future<void> askAdvisor(String question) async {
    final value = question.trim();
    if (value.isEmpty || advisorStatus == PracticeStatus.loading) {
      return;
    }
    _lastQuestion = value;
    advisorStatus = PracticeStatus.loading;
    advisorError = null;
    _notify();
    try {
      advisorAnswer = await _repository.askAdvisor(value);
      advisorStatus = PracticeStatus.success;
    } catch (error) {
      advisorError = _code(error);
      advisorStatus = PracticeStatus.error;
    }
    _notify();
  }

  Future<void> retryAdvisor() =>
      _lastQuestion == null ? Future.value() : askAdvisor(_lastQuestion!);

  Future<void> evaluateWriting(String task, String essay) async {
    final cleanTask = task.trim();
    final cleanEssay = essay.trim();
    if (cleanTask.isEmpty ||
        cleanEssay.isEmpty ||
        writingStatus == PracticeStatus.loading) {
      return;
    }
    _lastTask = cleanTask;
    _lastEssay = cleanEssay;
    writingStatus = PracticeStatus.loading;
    writingError = null;
    _notify();
    try {
      writingResult = await _repository.evaluateWriting(cleanTask, cleanEssay);
      writingStatus = PracticeStatus.success;
    } catch (error) {
      writingError = _code(error);
      writingStatus = PracticeStatus.error;
    }
    _notify();
  }

  Future<void> retryWriting() => _lastTask == null || _lastEssay == null
      ? Future.value()
      : evaluateWriting(_lastTask!, _lastEssay!);

  Future<void> startRecording(String prompt) async {
    if (recording || speakingStatus == PracticeStatus.loading) return;
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty) {
      speakingError = 'invalid_prompt';
      speakingStatus = PracticeStatus.error;
      _notify();
      return;
    }
    speakingError = null;
    speakingScore = null;
    _speakingPrompt = cleanPrompt;
    try {
      if (!await _recorder.start()) {
        speakingError = 'microphone_permission_denied';
        speakingStatus = PracticeStatus.error;
        _notify();
        return;
      }
      recording = true;
      recordingSeconds = 0;
      speakingStatus = PracticeStatus.idle;
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        recordingSeconds++;
        _notify();
        if (recordingSeconds >= 120) unawaited(stopAndScore());
      });
      _notify();
    } catch (error) {
      speakingError = _code(error);
      speakingStatus = PracticeStatus.error;
      _notify();
    }
  }

  Future<void> stopAndScore() async {
    if (!recording || speakingStatus == PracticeStatus.loading) return;
    _recordingTimer?.cancel();
    recording = false;
    try {
      _pendingAudio = await _recorder.stop();
      if (_pendingAudio == null || _pendingAudio!.bytes.isEmpty) {
        speakingError = 'audio_empty';
        speakingStatus = PracticeStatus.error;
        _notify();
        return;
      }
      if (_pendingAudio!.bytes.length > 10 * 1024 * 1024) {
        _pendingAudio = null;
        speakingError = 'audio_too_large';
        speakingStatus = PracticeStatus.error;
        _notify();
        return;
      }
      await _scorePending();
    } catch (error) {
      speakingError = _code(error);
      speakingStatus = PracticeStatus.error;
      _notify();
    }
  }

  Future<void> retrySpeaking() => _scorePending();

  Future<void> _scorePending() async {
    final audio = _pendingAudio;
    final prompt = _speakingPrompt;
    if (audio == null ||
        prompt == null ||
        speakingStatus == PracticeStatus.loading) {
      return;
    }
    speakingStatus = PracticeStatus.loading;
    speakingError = null;
    _notify();
    try {
      speakingScore = await _repository.scoreSpeaking(prompt, audio);
      _pendingAudio = null;
      speakingStatus = PracticeStatus.success;
      await loadHistory();
    } catch (error) {
      speakingError = _code(error);
      speakingStatus = PracticeStatus.error;
    }
    _notify();
  }

  Future<void> cancelRecording() async {
    _recordingTimer?.cancel();
    recording = false;
    _pendingAudio = null;
    await _recorder.cancel();
    _notify();
  }

  Future<void> loadHistory() async {
    if (historyStatus == PracticeStatus.loading) return;
    historyStatus = PracticeStatus.loading;
    historyError = null;
    _notify();
    try {
      history = await _repository.speakingHistory();
      historyStatus = PracticeStatus.success;
    } catch (error) {
      history = const [];
      historyError = _code(error);
      historyStatus = PracticeStatus.error;
    }
    _notify();
  }

  static String _code(Object error) =>
      error is ApiException ? error.code : 'unexpected_error';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _recordingTimer?.cancel();
    unawaited(_disposeRecorder());
    super.dispose();
  }

  Future<void> _disposeRecorder() async {
    if (recording) await _recorder.cancel();
    await _recorder.dispose();
  }
}
