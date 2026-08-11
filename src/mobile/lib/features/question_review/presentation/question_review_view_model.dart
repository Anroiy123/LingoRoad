import 'package:flutter/foundation.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/question_review/data/question_review_repository.dart';
import 'package:lingoroad_mobile/features/question_review/domain/question_review_models.dart';
import 'package:uuid/uuid.dart';

enum QuestionReviewState { initial, loading, ready, checking, feedback, grading, empty, error, complete }
enum _RetryAction { load, check, grade }

class QuestionReviewViewModel extends ChangeNotifier {
  QuestionReviewViewModel(
    this._repository, {
    Uuid? uuid,
    int sessionGeneration = 0,
  })  : _uuid = uuid ?? const Uuid(),
        _sessionGeneration = sessionGeneration;

  final QuestionReviewRepository _repository;
  final Uuid _uuid;
  int _sessionGeneration;
  int _requestGeneration = 0;
  bool _disposed = false;
  QuestionReviewState _state = QuestionReviewState.initial;
  List<QuestionReviewItem> _items = const [];
  int _totalDue = 0;
  int _index = 0;
  String _answer = '';
  String? _errorCode;
  QuestionReviewCheck? _feedback;
  String? _operationId;
  int? _pendingRating;
  int _correctCount = 0;
  int _incorrectCount = 0;
  int _xp = 0;
  int _coins = 0;
  bool _hasMoreDue = false;
  _RetryAction _retryAction = _RetryAction.load;

  QuestionReviewState get state => _state;
  QuestionReviewItem? get current => _index < _items.length ? _items[_index] : null;
  int get dueCount => _totalDue;
  int get remaining => _items.length - _index;
  int get completed => _index;
  String get answer => _answer;
  String? get errorCode => _errorCode;
  QuestionReviewCheck? get feedback => _feedback;
  int get correctCount => _correctCount;
  int get incorrectCount => _incorrectCount;
  int get xp => _xp;
  int get coins => _coins;
  bool get hasMoreDue => _hasMoreDue;
  int get sessionGeneration => _sessionGeneration;
  bool get isBusy => _state == QuestionReviewState.loading || _state == QuestionReviewState.checking || _state == QuestionReviewState.grading;
  bool get hasRetainedAnswerError => _retryAction != _RetryAction.load;

  void updateSessionGeneration(int value) {
    if (_sessionGeneration == value) return;
    _sessionGeneration = value;
    _requestGeneration++;
    _state = QuestionReviewState.initial;
    _items = const [];
    _totalDue = 0;
    _index = 0;
    _answer = '';
    _errorCode = null;
    _feedback = null;
    _operationId = null;
    _pendingRating = null;
    _correctCount = 0;
    _incorrectCount = 0;
    _xp = 0;
    _coins = 0;
    _hasMoreDue = false;
    _retryAction = _RetryAction.load;
    final resetGeneration = _requestGeneration;
    Future<void>.microtask(() {
      if (_isCurrent(resetGeneration)) notifyListeners();
    });
  }

  void setAnswer(String value) {
    if (isBusy || _state == QuestionReviewState.feedback || _state == QuestionReviewState.complete) return;
    _answer = value;
    notifyListeners();
  }

  Future<void> load({bool force = false, bool preserveSummary = false}) async {
    if (isBusy && !force) return;
    final requestGeneration = ++_requestGeneration;
    _state = QuestionReviewState.loading;
    _errorCode = null;
    _retryAction = _RetryAction.load;
    notifyListeners();
    try {
      final session = await _repository.fetchDue();
      if (!_isCurrent(requestGeneration)) return;
      _items = session.items;
      _totalDue = session.totalDue;
      _hasMoreDue = session.totalDue > session.items.length;
      _index = 0;
      _answer = '';
      _feedback = null;
      _operationId = null;
      _pendingRating = null;
      if (!preserveSummary) {
        _correctCount = 0;
        _incorrectCount = 0;
        _xp = 0;
        _coins = 0;
      }
      _state = _items.isEmpty ? QuestionReviewState.empty : QuestionReviewState.ready;
    } catch (error) {
      if (!_isCurrent(requestGeneration)) return;
      _toError(error, _RetryAction.load);
    }
    if (_isCurrent(requestGeneration)) notifyListeners();
  }

  Future<void> check([String? submittedAnswer]) async {
    if (submittedAnswer != null) _answer = submittedAnswer;
    final item = current;
    if (item == null || isBusy || _answer.trim().isEmpty) return;
    _state = QuestionReviewState.checking;
    _errorCode = null;
    final requestGeneration = _requestGeneration;
    notifyListeners();
    try {
      final feedback = await _repository.check(item: item, answer: _answer);
      if (!_isCurrent(requestGeneration)) return;
      _feedback = feedback;
      if (_feedback!.correct) {
        _state = QuestionReviewState.feedback;
      } else {
        await _grade(
          item,
          1,
          automatic: true,
          requestGeneration: requestGeneration,
        );
      }
    } catch (error) {
      if (!_isCurrent(requestGeneration)) return;
      if (_isStaleCard(error)) {
        await load(force: true, preserveSummary: true);
        return;
      }
      _toError(error, _RetryAction.check);
    }
    if (_isCurrent(requestGeneration)) notifyListeners();
  }

  Future<void> grade(int rating) async {
    final item = current;
    if (item == null || _feedback?.correct != true || isBusy || rating < 2 || rating > 4) return;
    await _grade(item, rating);
    notifyListeners();
  }

  Future<void> _grade(
    QuestionReviewItem item,
    int rating, {
    bool automatic = false,
    int? requestGeneration,
  }) async {
    final activeGeneration = requestGeneration ?? _requestGeneration;
    if (!_isCurrent(activeGeneration)) return;
    _state = QuestionReviewState.grading;
    _errorCode = null;
    _operationId ??= _uuid.v4();
    _pendingRating = rating;
    notifyListeners();
    try {
      final grade = await _repository.grade(
        item: item,
        rating: rating,
        operationId: _operationId!,
        expectedReps: item.reps,
        answer: _answer,
      );
      if (!_isCurrent(activeGeneration)) return;
      _xp += grade.xp;
      _coins += grade.coins;
      if (_feedback!.correct) {
        _correctCount++;
      } else {
        _incorrectCount++;
      }
      _operationId = null;
      _pendingRating = null;
      _state = QuestionReviewState.feedback;
      if (!automatic) await _advance();
    } catch (error) {
      if (!_isCurrent(activeGeneration)) return;
      if (_isStaleCard(error)) {
        await load(force: true, preserveSummary: true);
        return;
      }
      _toError(error, _RetryAction.grade);
    }
  }

  Future<void> next() async {
    if (_state != QuestionReviewState.feedback || _feedback == null || (_feedback!.correct && _operationId != null)) return;
    final requestGeneration = _requestGeneration;
    await _advance();
    if (_isCurrent(requestGeneration)) notifyListeners();
  }

  Future<void> _advance() async {
    _index++;
    _answer = '';
    _feedback = null;
    if (_index < _items.length) {
      _state = QuestionReviewState.ready;
      return;
    }
    _state = QuestionReviewState.complete;
    final requestGeneration = _requestGeneration;
    try {
      final session = await _repository.fetchDue();
      if (!_isCurrent(requestGeneration)) return;
      _totalDue = session.totalDue;
      _hasMoreDue = session.totalDue > 0;
    } catch (_) {
      // Completion remains usable; keep the pre-session pagination signal.
    }
  }

  Future<void> retry() => switch (_retryAction) {
        _RetryAction.load => load(),
        _RetryAction.check => check(),
        _RetryAction.grade => _retryGrade(),
      };

  Future<void> _retryGrade() async {
    final item = current;
    final correct = _feedback?.correct;
    if (item == null || correct == null) return;
    await _grade(item, _pendingRating ?? (correct ? 3 : 1), automatic: !correct);
    if (correct && _state == QuestionReviewState.feedback) await _advance();
    notifyListeners();
  }

  void _toError(Object error, _RetryAction action) {
    _state = QuestionReviewState.error;
    _retryAction = action;
    _errorCode = error is ApiException ? error.code : 'unexpected_error';
  }

  bool _isStaleCard(Object error) {
    if (error is! ApiException) return false;
    return error.statusCode == 404 ||
        error.code == 'review_not_due' ||
        error.code == 'review_already_graded';
  }

  bool _isCurrent(int requestGeneration) =>
      !_disposed && requestGeneration == _requestGeneration;

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration++;
    super.dispose();
  }
}
