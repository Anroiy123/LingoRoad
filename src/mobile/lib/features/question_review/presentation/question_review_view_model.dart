import 'package:flutter/foundation.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/question_review/data/question_review_repository.dart';
import 'package:lingoroad_mobile/features/question_review/domain/question_review_models.dart';
import 'package:uuid/uuid.dart';

enum QuestionReviewState { initial, loading, ready, checking, feedback, grading, empty, error, complete }
enum _RetryAction { load, check, grade }

class QuestionReviewViewModel extends ChangeNotifier {
  QuestionReviewViewModel(this._repository, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final QuestionReviewRepository _repository;
  final Uuid _uuid;
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
  bool get isBusy => _state == QuestionReviewState.loading || _state == QuestionReviewState.checking || _state == QuestionReviewState.grading;

  void setAnswer(String value) {
    if (isBusy || _state == QuestionReviewState.feedback || _state == QuestionReviewState.complete) return;
    _answer = value;
    notifyListeners();
  }

  Future<void> load() async {
    if (isBusy) return;
    _state = QuestionReviewState.loading;
    _errorCode = null;
    _retryAction = _RetryAction.load;
    notifyListeners();
    try {
      final session = await _repository.fetchDue();
      _items = session.items;
      _totalDue = session.totalDue;
      _index = 0;
      _answer = '';
      _feedback = null;
      _operationId = null;
      _pendingRating = null;
      _correctCount = 0;
      _incorrectCount = 0;
      _xp = 0;
      _coins = 0;
      _state = _items.isEmpty ? QuestionReviewState.empty : QuestionReviewState.ready;
    } catch (error) {
      _toError(error, _RetryAction.load);
    }
    notifyListeners();
  }

  Future<void> check([String? submittedAnswer]) async {
    if (submittedAnswer != null) _answer = submittedAnswer;
    final item = current;
    if (item == null || isBusy || _answer.trim().isEmpty) return;
    _state = QuestionReviewState.checking;
    _errorCode = null;
    notifyListeners();
    try {
      _feedback = await _repository.check(item: item, answer: _answer);
      if (_feedback!.correct) {
        _correctCount++;
        _state = QuestionReviewState.feedback;
      } else {
        _incorrectCount++;
        await _grade(item, 1, automatic: true);
      }
    } catch (error) {
      _toError(error, _RetryAction.check);
    }
    notifyListeners();
  }

  Future<void> grade(int rating) async {
    final item = current;
    if (item == null || _feedback?.correct != true || isBusy || rating < 2 || rating > 4) return;
    await _grade(item, rating);
    notifyListeners();
  }

  Future<void> _grade(QuestionReviewItem item, int rating, {bool automatic = false}) async {
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
      _xp += grade.xp;
      _coins += grade.coins;
      _operationId = null;
      _pendingRating = null;
      _state = QuestionReviewState.feedback;
      if (!automatic) _advance();
    } catch (error) {
      _toError(error, _RetryAction.grade);
    }
  }

  void next() {
    if (_state != QuestionReviewState.feedback || _feedback == null || (_feedback!.correct && _operationId != null)) return;
    _advance();
    notifyListeners();
  }

  void _advance() {
    _index++;
    _answer = '';
    _feedback = null;
    _state = _index >= _items.length ? QuestionReviewState.complete : QuestionReviewState.ready;
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
    if (correct && _state == QuestionReviewState.feedback) _advance();
    notifyListeners();
  }

  void _toError(Object error, _RetryAction action) {
    _state = QuestionReviewState.error;
    _retryAction = action;
    _errorCode = error is ApiException ? error.code : 'unexpected_error';
  }
}
