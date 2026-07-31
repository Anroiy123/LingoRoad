import 'package:flutter/foundation.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/learning_path/data/learning_path_repository.dart';
import 'package:lingoroad_mobile/features/learning_path/domain/learning_path_models.dart';

enum LearningPathState { initial, loading, success, empty, error }

class LearningPathViewModel extends ChangeNotifier {
  LearningPathViewModel(this._repository);

  final LearningPathRepository _repository;

  LearningPathState _state = LearningPathState.initial;
  List<LearningPathStep> _steps = const [];
  String? _errorCode;

  LearningPathState get state => _state;
  List<LearningPathStep> get steps => _steps;
  String? get errorCode => _errorCode;

  Future<void> load() async {
    if (_state == LearningPathState.loading) {
      return;
    }

    _state = LearningPathState.loading;
    _errorCode = null;
    notifyListeners();

    try {
      final steps = await _repository.fetch();
      _steps = steps;
      _state =
          steps.isEmpty ? LearningPathState.empty : LearningPathState.success;
    } catch (error) {
      _steps = const [];
      _errorCode = error is ApiException ? error.code : 'unexpected_error';
      _state = LearningPathState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => load();
}
