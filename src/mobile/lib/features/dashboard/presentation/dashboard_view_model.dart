import 'package:flutter/foundation.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:lingoroad_mobile/features/dashboard/domain/dashboard_models.dart';

enum DashboardState { initial, loading, ready, error }

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel(this._repository);

  final DashboardRepository _repository;
  DashboardState _state = DashboardState.initial;
  DashboardData? _dashboard;
  List<QuestData> _quests = const [];
  String? _errorCode;

  DashboardState get state => _state;
  DashboardData? get dashboard => _dashboard;
  List<QuestData> get quests => _quests;
  String? get errorCode => _errorCode;

  Future<void> load() async {
    if (_state == DashboardState.loading) return;
    _state = DashboardState.loading;
    _errorCode = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.dashboard(),
        _repository.quests(),
      ]);
      _dashboard = results[0] as DashboardData;
      _quests = results[1] as List<QuestData>;
      _state = DashboardState.ready;
    } catch (error) {
      _dashboard = null;
      _quests = const [];
      _errorCode = error is ApiException ? error.code : 'unexpected_error';
      _state = DashboardState.error;
    }
    notifyListeners();
  }

  Future<void> retry() => load();
}
