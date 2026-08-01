import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/progress/data/progress_repository.dart';
import 'package:lingoroad_mobile/features/progress/domain/progress_models.dart';

enum ProgressState { initial, loading, ready, empty, error }

class ProgressViewModel extends ChangeNotifier {
  ProgressViewModel(this._repository);
  final ProgressRepository _repository;
  ProgressState _state = ProgressState.initial;
  List<SkillCatalogItem>? _catalog;
  List<CategoryProgress> _categories = const [];
  String? _errorCode;
  ProgressState get state => _state;
  List<CategoryProgress> get categories => _categories;
  String? get errorCode => _errorCode;
  List<CategoryProgress> get strengths =>
      _categories.where((e) => e.practiced && e.percent >= 80).take(3).toList();
  List<CategoryProgress> get improvements =>
      _categories.where((e) => e.practiced && e.percent < 80).take(3).toList();
  String? get weakest => improvements.isEmpty
      ? null
      : (improvements.toList()..sort((a, b) => a.percent.compareTo(b.percent)))
          .first
          .category;
  Future<void> load() async {
    if (_state == ProgressState.loading) return;
    _state = ProgressState.loading;
    _errorCode = null;
    notifyListeners();
    try {
      final results = await Future.wait(
          [if (_catalog == null) _repository.skills(), _repository.mastery()]);
      _catalog ??= results.first as List<SkillCatalogItem>;
      final mastery = results.last as List<MasteryRow>;
      _categories = aggregate(_catalog!, mastery);
      _state = _catalog!.isEmpty ? ProgressState.empty : ProgressState.ready;
    } catch (e) {
      _state = ProgressState.error;
      _errorCode = e is ApiException ? e.code : 'unexpected_error';
    }
    notifyListeners();
  }

  static List<CategoryProgress> aggregate(
      List<SkillCatalogItem> catalog, List<MasteryRow> mastery) {
    final parentIds = catalog
        .where((s) => s.parentId != null)
        .map((s) => s.parentId!)
        .toSet();
    final leafList = catalog.where((s) => !parentIds.contains(s.id)).toList();
    final values = {for (final row in mastery) row.code: row.value};
    final grouped = <String, List<SkillCatalogItem>>{};
    for (final s in leafList) {
      grouped.putIfAbsent(s.category, () => []).add(s);
    }
    const preferred = [
      'grammar',
      'vocabulary',
      'reading',
      'listening',
      'writing'
    ];
    final names = grouped.keys.toList()
      ..sort((a, b) {
        final ai = preferred.indexOf(a), bi = preferred.indexOf(b);
        if (ai < 0 && bi < 0) return a.compareTo(b);
        if (ai < 0) return 1;
        if (bi < 0) return -1;
        return ai.compareTo(bi);
      });
    return [
      for (final category in names)
        () {
          final rows = grouped[category]!;
          final known = rows.where((s) => values.containsKey(s.code)).toList();
          final average = rows
                  .map((s) => (values[s.code] ?? 0).clamp(0, 1))
                  .reduce((a, b) => a + b) /
              rows.length;
          return CategoryProgress(
              category, (average * 100).round(), known.isNotEmpty);
        }()
    ];
  }
}
