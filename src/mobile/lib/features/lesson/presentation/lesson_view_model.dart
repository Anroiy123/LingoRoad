import 'package:flutter/foundation.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/lesson/data/lesson_repository.dart';
import 'package:lingoroad_mobile/features/lesson/domain/lesson_models.dart';
import 'package:uuid/uuid.dart';

enum LessonState {
  initial,
  loading,
  ready,
  submitting,
  feedback,
  completing,
  completed,
  error,
}

class LessonViewModel extends ChangeNotifier {
  LessonViewModel(this._repository, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final LessonRepository _repository;
  final Uuid _uuid;
  LessonState _state = LessonState.initial;
  LessonAttempt? _attempt;
  LessonCompletion? _completion;
  ExerciseFeedback? _feedback;
  int _index = 0;
  String? _errorCode;
  String? _startOperationId;
  String? _answerOperationId;
  String? _pendingAnswer;
  String? _completeOperationId;
  String? _lessonId;

  LessonState get state => _state;
  LessonAttempt? get attempt => _attempt;
  LessonExercise? get current =>
      _attempt != null && _index < _attempt!.exercises.length
          ? _attempt!.exercises[_index]
          : null;
  LessonCompletion? get completion => _completion;
  ExerciseFeedback? get feedback => _feedback;
  String? get errorCode => _errorCode;
  int get currentNumber => _index + 1;
  int get total => _attempt?.exercises.length ?? 0;
  double get progress => total == 0 ? 0 : _index / total;
  bool get busy =>
      _state == LessonState.loading ||
      _state == LessonState.submitting ||
      _state == LessonState.completing;

  Future<void> load(String lessonId) async {
    if (busy) return;
    _lessonId = lessonId;
    _startOperationId ??= _uuid.v4();
    _state = LessonState.loading;
    _errorCode = null;
    notifyListeners();
    try {
      _attempt = await _repository.start(lessonId, _startOperationId!);
      _startOperationId = null;
      _index = _attempt!.exercises.indexWhere((exercise) => !exercise.answered);
      if (_index < 0) {
        _index = _attempt!.exercises.length;
        await _complete();
        return;
      }
      _state = LessonState.ready;
    } catch (error) {
      _errorCode = error is ApiException ? error.code : 'unexpected_error';
      _state = LessonState.error;
    }
    notifyListeners();
  }

  Future<void> retryLoad() async {
    final lessonId = _lessonId;
    if (lessonId != null) await load(lessonId);
  }

  Future<void> submit(String answer) async {
    final exercise = current;
    final normalized = answer.trim();
    if (exercise == null ||
        busy ||
        _state == LessonState.feedback ||
        normalized.isEmpty) {
      return;
    }
    _answerOperationId ??= _uuid.v4();
    _pendingAnswer ??= normalized;
    _state = LessonState.submitting;
    _errorCode = null;
    notifyListeners();
    try {
      _feedback = await _repository.submit(
        exerciseId: exercise.id,
        answer: _pendingAnswer!,
        operationId: _answerOperationId!,
      );
      _answerOperationId = null;
      _pendingAnswer = null;
      _state = LessonState.feedback;
    } catch (error) {
      _errorCode = error is ApiException ? error.code : 'unexpected_error';
      _state = LessonState.ready;
    }
    notifyListeners();
  }

  Future<void> retryAnswer() async {
    final answer = _pendingAnswer;
    if (answer != null) await submit(answer);
  }

  Future<void> next() async {
    if (_state != LessonState.feedback) return;
    _feedback = null;
    _index++;
    if (_index >= total) {
      await _complete();
    } else {
      _state = LessonState.ready;
      notifyListeners();
    }
  }

  Future<void> _complete() async {
    final attempt = _attempt;
    if (attempt == null || _state == LessonState.completing) return;
    _completeOperationId ??= _uuid.v4();
    _state = LessonState.completing;
    _errorCode = null;
    notifyListeners();
    try {
      _completion =
          await _repository.complete(attempt.id, _completeOperationId!);
      _completeOperationId = null;
      _state = LessonState.completed;
    } catch (error) {
      _errorCode = error is ApiException ? error.code : 'unexpected_error';
      _state = LessonState.error;
    }
    notifyListeners();
  }

  Future<void> retryComplete() => _complete();
}
