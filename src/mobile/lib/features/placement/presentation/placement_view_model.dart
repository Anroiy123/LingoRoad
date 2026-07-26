import 'package:flutter/foundation.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/placement/data/placement_repository.dart';
import 'package:lingoroad_mobile/features/placement/domain/placement_models.dart';

class PlacementViewModel extends ChangeNotifier {
  PlacementViewModel(this._repository);

  final PlacementRepository _repository;

  String? _sessionId;
  PlacementItem? _currentItem;
  PlacementResult? _result;
  String? _selectedAnswer;
  String? _errorMessage;
  int _questionNumber = 0;
  bool _isLoading = false;

  String? get sessionId => _sessionId;
  PlacementItem? get currentItem => _currentItem;
  PlacementResult? get result => _result;
  String? get selectedAnswer => _selectedAnswer;
  String? get errorMessage => _errorMessage;
  int get questionNumber => _questionNumber;
  bool get isLoading => _isLoading;
  bool get canSubmit => !_isLoading && _selectedAnswer != null;

  Future<bool> start() async {
    if (_isLoading) {
      return false;
    }
    _setLoading(true);
    _resetTest();
    try {
      final start = await _repository.start();
      _sessionId = start.sessionId;
      _currentItem = start.item;
      _questionNumber = 1;
      return true;
    } catch (error) {
      _errorMessage = _messageFor(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void selectAnswer(String answer) {
    final item = _currentItem;
    if (_isLoading || item == null || !item.options.contains(answer)) {
      return;
    }
    _selectedAnswer = answer;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> submitAnswer() async {
    final sessionId = _sessionId;
    final item = _currentItem;
    final answer = _selectedAnswer;
    if (_isLoading || sessionId == null || item == null || answer == null) {
      return false;
    }
    _setLoading(true);
    _errorMessage = null;
    try {
      final step = await _repository.answer(
        sessionId: sessionId,
        itemId: item.id,
        answer: answer,
      );
      _selectedAnswer = null;
      if (!step.done) {
        _currentItem = step.item;
        _questionNumber++;
        return false;
      }

      _currentItem = null;
      _result = PlacementResult(
        theta: step.theta!,
        se: step.se!,
        cefr: step.cefr!,
        itemsAnswered: _questionNumber,
        status: 'completed',
      );
      try {
        _result = await _repository.result(sessionId);
      } on ApiException {
        // The answer response already contains a complete result. Keep it as
        // a safe fallback when the follow-up result request is unavailable.
      }
      return true;
    } catch (error) {
      _errorMessage = _messageFor(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _resetTest() {
    _sessionId = null;
    _currentItem = null;
    _result = null;
    _selectedAnswer = null;
    _errorMessage = null;
    _questionNumber = 0;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _messageFor(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        'empty_item_bank' => 'Ngân hàng câu hỏi hiện đang trống.',
        'ml_service_unavailable' => 'Dịch vụ chấm điểm tạm thời chưa sẵn sàng.',
        'request_timeout' => 'Kết nối quá thời gian chờ.',
        'network_unavailable' => 'Không thể kết nối đến máy chủ.',
        'session_completed' => 'Bài kiểm tra này đã hoàn thành.',
        _ => 'Không thể tải bài kiểm tra. Vui lòng thử lại.',
      };
    }
    return 'Đã xảy ra lỗi. Vui lòng thử lại.';
  }
}
