import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';

enum SessionStatus { checking, unauthenticated, authenticated }

enum PlacementOnboardingStatus {
  unknown,
  checking,
  required,
  completed,
  error,
}

typedef PlacementStatusLoader = Future<bool> Function();

class SessionController extends ChangeNotifier {
  SessionController(this._store);

  final SessionStore _store;
  SessionStatus _status = SessionStatus.checking;
  PlacementOnboardingStatus _placementStatus =
      PlacementOnboardingStatus.unknown;
  String? _token;
  PlacementStatusLoader? _placementStatusLoader;
  int _sessionEpoch = 0;
  int _placementLookupGeneration = 0;
  Future<void> _storeQueue = Future<void>.value();

  SessionStatus get status => _status;
  PlacementOnboardingStatus get placementStatus => _placementStatus;
  String? get token => _token;

  void configurePlacementStatusLoader(PlacementStatusLoader loader) {
    _placementStatusLoader = loader;
  }

  Future<void> restore() async {
    final epoch = ++_sessionEpoch;
    _placementLookupGeneration++;
    String? stored;
    try {
      final value = (await _enqueueStore(_store.readToken))?.trim();
      stored = value == null || value.isEmpty ? null : value;
    } catch (_) {
      stored = null;
    }
    if (epoch != _sessionEpoch) {
      return;
    }
    _token = stored;
    if (_token == null) {
      _setSession(
        status: SessionStatus.unauthenticated,
        placementStatus: PlacementOnboardingStatus.unknown,
      );
      return;
    }
    _setSession(
      status: SessionStatus.authenticated,
      placementStatus: PlacementOnboardingStatus.checking,
    );
    await refreshPlacementStatus();
  }

  Future<void> authenticate(
    String token, {
    bool checkPlacement = true,
  }) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(token, 'token', 'Token không được để trống');
    }
    final epoch = ++_sessionEpoch;
    _placementLookupGeneration++;
    await _enqueueStore(() => _store.writeToken(normalized));
    if (epoch != _sessionEpoch) {
      return;
    }
    _token = normalized;
    _setSession(
      status: SessionStatus.authenticated,
      placementStatus: checkPlacement
          ? PlacementOnboardingStatus.checking
          : PlacementOnboardingStatus.required,
    );
    if (checkPlacement) {
      await refreshPlacementStatus();
    }
  }

  Future<void> refreshPlacementStatus() async {
    if (_status != SessionStatus.authenticated || _token == null) {
      return;
    }
    final loader = _placementStatusLoader;
    if (loader == null) {
      _setPlacementStatus(PlacementOnboardingStatus.required);
      return;
    }

    final token = _token!;
    final epoch = _sessionEpoch;
    final generation = ++_placementLookupGeneration;
    _setPlacementStatus(PlacementOnboardingStatus.checking);
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final completed = await loader();
        if (!_isCurrentPlacementLookup(token, epoch, generation)) {
          return;
        }
        _setPlacementStatus(
          completed
              ? PlacementOnboardingStatus.completed
              : PlacementOnboardingStatus.required,
        );
        return;
      } catch (_) {
        if (!_isCurrentPlacementLookup(token, epoch, generation)) {
          return;
        }
      }
    }
    if (_isCurrentPlacementLookup(token, epoch, generation)) {
      _setPlacementStatus(PlacementOnboardingStatus.error);
    }
  }

  void markPlacementCompleted() {
    if (_status == SessionStatus.authenticated) {
      _placementLookupGeneration++;
      _setPlacementStatus(PlacementOnboardingStatus.completed);
    }
  }

  Future<void> logout() async {
    _sessionEpoch++;
    _placementLookupGeneration++;
    _token = null;
    _setSession(
      status: SessionStatus.unauthenticated,
      placementStatus: PlacementOnboardingStatus.unknown,
    );
    await _enqueueStore(_store.clearToken);
  }

  Future<void> invalidate() => logout();

  bool _isCurrentPlacementLookup(
    String token,
    int epoch,
    int generation,
  ) =>
      _status == SessionStatus.authenticated &&
      _token == token &&
      _sessionEpoch == epoch &&
      _placementLookupGeneration == generation;

  Future<T> _enqueueStore<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _storeQueue = _storeQueue.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void _setSession({
    required SessionStatus status,
    required PlacementOnboardingStatus placementStatus,
  }) {
    if (_status == status && _placementStatus == placementStatus) {
      return;
    }
    _status = status;
    _placementStatus = placementStatus;
    notifyListeners();
  }

  void _setPlacementStatus(PlacementOnboardingStatus value) {
    if (_placementStatus == value) {
      return;
    }
    _placementStatus = value;
    notifyListeners();
  }
}
