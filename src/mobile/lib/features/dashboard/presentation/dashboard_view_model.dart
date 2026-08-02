import 'package:flutter/foundation.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:lingoroad_mobile/features/dashboard/domain/dashboard_models.dart';

enum DashboardState { initial, loading, ready, error }

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel(this._repository, {int sessionGeneration = 0})
      : _sessionGeneration = sessionGeneration;

  final DashboardRepository _repository;
  int _sessionGeneration;
  DashboardState _state = DashboardState.initial;
  DashboardData? _dashboard;
  List<QuestData> _quests = const [];
  String? _errorCode;
  bool _disposed = false;
  int _loadGeneration = 0;

  DashboardState get state => _state;
  DashboardData? get dashboard => _dashboard;
  List<QuestData> get quests => _quests;
  String? get errorCode => _errorCode;
  int get sessionGeneration => _sessionGeneration;

  void updateSessionGeneration(int value) {
    if (_sessionGeneration == value) return;
    _loadGeneration++;
    _sessionGeneration = value;
    _state = DashboardState.initial;
    _dashboard = null;
    _quests = const [];
    _errorCode = null;
  }

  Future<void> load() async {
    if (_state == DashboardState.loading) return;
    final loadGeneration = ++_loadGeneration;
    _state = DashboardState.loading;
    _errorCode = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.dashboard(),
        _repository.quests(),
      ]);
      if (_disposed || loadGeneration != _loadGeneration) return;
      _dashboard = results[0] as DashboardData;
      _quests = results[1] as List<QuestData>;
      _state = DashboardState.ready;
    } catch (error) {
      if (_disposed || loadGeneration != _loadGeneration) return;
      _dashboard = null;
      _quests = const [];
      _errorCode = error is ApiException ? error.code : 'unexpected_error';
      _state = DashboardState.error;
    }
    if (_disposed || loadGeneration != _loadGeneration) return;
    notifyListeners();
  }

  Future<void> retry() => load();

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    super.dispose();
  }
}
