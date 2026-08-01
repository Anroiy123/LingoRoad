import 'package:flutter/foundation.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/review/data/review_repository.dart';
import 'package:lingoroad_mobile/features/review/domain/review_models.dart';
import 'package:uuid/uuid.dart';

enum ReviewState { initial, loading, ready, empty, error, complete }

class ReviewViewModel extends ChangeNotifier {
  ReviewViewModel(this._repository, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();
  final ReviewRepository _repository;
  final Uuid _uuid;
  ReviewState _state = ReviewState.initial;
  List<ReviewCard> _cards = const [];
  int _index = 0;
  bool _gradePending = false;
  String? _errorCode;
  String? _operationId;
  ReviewState get state => _state;
  ReviewCard? get current => _index < _cards.length ? _cards[_index] : null;
  int get remaining => _cards.length - _index;
  bool get gradePending => _gradePending;
  String? get errorCode => _errorCode;
  Future<void> load() async {
    if (_state == ReviewState.loading || _gradePending) return;
    _state = ReviewState.loading;
    _errorCode = null;
    notifyListeners();
    try {
      _cards = await _repository.fetchDue();
      _index = 0;
      _operationId = null;
      _state = _cards.isEmpty ? ReviewState.empty : ReviewState.ready;
    } catch (e) {
      _state = ReviewState.error;
      _errorCode = e is ApiException ? e.code : 'unexpected_error';
    }
    notifyListeners();
  }

  Future<void> grade(int rating) async {
    final card = current;
    if (card == null || _gradePending || rating < 1 || rating > 4) return;
    _gradePending = true;
    _errorCode = null;
    _operationId ??= _uuid.v4();
    notifyListeners();
    try {
      await _repository.grade(
          card: card, rating: rating, operationId: _operationId!);
      _index++;
      _operationId = null;
      _state =
          _index == _cards.length ? ReviewState.complete : ReviewState.ready;
    } catch (e) {
      final api = e is ApiException ? e : null;
      _errorCode = api?.code ?? 'unexpected_error';
      if (api?.statusCode == 404 || api?.code == 'review_already_graded') {
        _gradePending = false;
        await load();
        return;
      }
    }
    _gradePending = false;
    notifyListeners();
  }
}
