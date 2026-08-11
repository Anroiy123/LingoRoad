import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';

enum SessionStatus { checking, unauthenticated, authenticated }

enum PlacementOnboardingStatus { unknown, checking, required, completed, error }

enum ProfileSetupStatus { unknown, checking, required, completed, error }

typedef PlacementStatusLoader = Future<bool> Function();
typedef ProfileSetupStatusLoader = Future<bool> Function();

class SessionController extends ChangeNotifier {
  SessionController(
    this._store, {
    Duration storeReadTimeout = const Duration(seconds: 5),
    Duration storeOperationTimeout = const Duration(seconds: 5),
    Duration placementStatusTimeout = const Duration(seconds: 8),
  }) : assert(storeReadTimeout > Duration.zero),
       assert(storeOperationTimeout > Duration.zero),
       assert(placementStatusTimeout > Duration.zero),
       _storeReadTimeout = storeReadTimeout,
       _storeOperationTimeout = storeOperationTimeout,
       _placementStatusTimeout = placementStatusTimeout;

  final SessionStore _store;
  final Duration _storeReadTimeout;
  final Duration _storeOperationTimeout;
  final Duration _placementStatusTimeout;
  SessionStatus _status = SessionStatus.checking;
  PlacementOnboardingStatus _placementStatus =
      PlacementOnboardingStatus.unknown;
  ProfileSetupStatus _profileSetupStatus = ProfileSetupStatus.unknown;
  String? _token;
  String? _refreshToken;
  PlacementStatusLoader? _placementStatusLoader;
  ProfileSetupStatusLoader? _profileSetupStatusLoader;
  int _sessionEpoch = 0;
  int _placementLookupGeneration = 0;
  int _profileSetupLookupGeneration = 0;
  Future<void> _storeQueue = Future<void>.value();

  SessionStatus get status => _status;
  PlacementOnboardingStatus get placementStatus => _placementStatus;
  ProfileSetupStatus get profileSetupStatus => _profileSetupStatus;
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  int get sessionGeneration => _sessionEpoch;

  void configurePlacementStatusLoader(PlacementStatusLoader loader) {
    _placementStatusLoader = loader;
  }

  void configureProfileSetupStatusLoader(ProfileSetupStatusLoader loader) {
    _profileSetupStatusLoader = loader;
  }

  Future<void> restore() async {
    final epoch = ++_sessionEpoch;
    _placementLookupGeneration++;
    _profileSetupLookupGeneration++;
    String? stored;
    String? storedRefresh;
    try {
      final storedToken = await _enqueueStore(
        _store.readToken,
        timeout: _storeReadTimeout,
      );
      final value = storedToken?.trim();
      stored = value == null || value.isEmpty ? null : value;
      if (_store case final RefreshSessionStore refreshStore) {
        final storedRefreshToken = await _enqueueStore(
          refreshStore.readRefreshToken,
          timeout: _storeReadTimeout,
        );
        final value = storedRefreshToken?.trim();
        storedRefresh = value == null || value.isEmpty ? null : value;
      }
    } catch (_) {
      stored = null;
    }
    if (epoch != _sessionEpoch) {
      return;
    }
    _token = stored;
    _refreshToken = storedRefresh;
    if (_token == null) {
      _setSession(
        status: SessionStatus.unauthenticated,
        placementStatus: PlacementOnboardingStatus.unknown,
        profileSetupStatus: ProfileSetupStatus.unknown,
      );
      return;
    }
    _setSession(
      status: SessionStatus.authenticated,
      placementStatus: PlacementOnboardingStatus.checking,
      profileSetupStatus: ProfileSetupStatus.unknown,
    );
    await refreshPlacementStatus();
  }

  Future<void> authenticate(
    String token, {
    String? refreshToken,
    bool checkPlacement = true,
  }) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(token, 'token', 'Token không được để trống');
    }
    final epoch = ++_sessionEpoch;
    _placementLookupGeneration++;
    _profileSetupLookupGeneration++;
    await _enqueueStore(() => _store.writeToken(normalized));
    if (refreshToken != null) {
      if (_store case final RefreshSessionStore refreshStore) {
        await _enqueueStore(() => refreshStore.writeRefreshToken(refreshToken));
      }
    }
    if (epoch != _sessionEpoch) {
      return;
    }
    _token = normalized;
    if (refreshToken != null) {
      _refreshToken = refreshToken;
    }
    _setSession(
      status: SessionStatus.authenticated,
      placementStatus: checkPlacement
          ? PlacementOnboardingStatus.checking
          : PlacementOnboardingStatus.required,
      profileSetupStatus: ProfileSetupStatus.unknown,
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
        final completed = await loader().timeout(_placementStatusTimeout);
        if (!_isCurrentPlacementLookup(token, epoch, generation)) {
          return;
        }
        _setPlacementStatus(
          completed
              ? PlacementOnboardingStatus.completed
              : PlacementOnboardingStatus.required,
        );
        if (completed) await refreshProfileSetupStatus();
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

  Future<void> markPlacementCompleted() async {
    if (_status == SessionStatus.authenticated) {
      _placementLookupGeneration++;
      _profileSetupLookupGeneration++;
      _setPlacementStatus(PlacementOnboardingStatus.completed);
      await refreshProfileSetupStatus();
    }
  }

  Future<void> refreshProfileSetupStatus() async {
    if (_status != SessionStatus.authenticated ||
        _placementStatus != PlacementOnboardingStatus.completed) {
      return;
    }
    final loader = _profileSetupStatusLoader;
    if (loader == null) {
      _setProfileSetupStatus(ProfileSetupStatus.completed);
      return;
    }
    final token = _token!;
    final epoch = _sessionEpoch;
    final generation = ++_profileSetupLookupGeneration;
    _setProfileSetupStatus(ProfileSetupStatus.checking);
    try {
      final completed = await loader().timeout(_placementStatusTimeout);
      if (_isCurrentProfileSetupLookup(token, epoch, generation)) {
        _setProfileSetupStatus(
          completed
              ? ProfileSetupStatus.completed
              : ProfileSetupStatus.required,
        );
      }
    } catch (_) {
      if (_isCurrentProfileSetupLookup(token, epoch, generation)) {
        _setProfileSetupStatus(ProfileSetupStatus.error);
      }
    }
  }

  void markProfileSetupCompleted() {
    if (_status == SessionStatus.authenticated) {
      _profileSetupLookupGeneration++;
      _setProfileSetupStatus(ProfileSetupStatus.completed);
    }
  }

  Future<void> logout() async {
    final epoch = ++_sessionEpoch;
    _placementLookupGeneration++;
    _profileSetupLookupGeneration++;
    await _enqueueStore(_store.clearToken, timeout: _storeOperationTimeout);
    if (_store case final RefreshSessionStore refreshStore) {
      await _enqueueStore(
        refreshStore.clearRefreshToken,
        timeout: _storeOperationTimeout,
      );
    }
    if (epoch != _sessionEpoch) {
      return;
    }
    _token = null;
    _refreshToken = null;
    _setSession(
      status: SessionStatus.unauthenticated,
      placementStatus: PlacementOnboardingStatus.unknown,
      profileSetupStatus: ProfileSetupStatus.unknown,
    );
  }

  Future<bool> updateTokens(
    String accessToken,
    String refreshToken, {
    required String expectedRefreshToken,
  }) async {
    final normalized = accessToken.trim();
    if (normalized.isEmpty || refreshToken.trim().isEmpty) {
      throw ArgumentError('Token không được để trống');
    }
    final epoch = _sessionEpoch;
    if (_status != SessionStatus.authenticated ||
        _refreshToken != expectedRefreshToken) {
      return false;
    }
    await _enqueueStore(() => _store.writeToken(normalized));
    if (_store case final RefreshSessionStore refreshStore) {
      await _enqueueStore(() => refreshStore.writeRefreshToken(refreshToken));
    }
    if (epoch != _sessionEpoch || _refreshToken != expectedRefreshToken) {
      return false;
    }
    _token = normalized;
    _refreshToken = refreshToken;
    notifyListeners();
    return true;
  }

  Future<void> invalidate() => logout();

  bool _isCurrentPlacementLookup(String token, int epoch, int generation) =>
      _status == SessionStatus.authenticated &&
      _token == token &&
      _sessionEpoch == epoch &&
      _placementLookupGeneration == generation;

  bool _isCurrentProfileSetupLookup(String token, int epoch, int generation) =>
      _status == SessionStatus.authenticated &&
      _token == token &&
      _sessionEpoch == epoch &&
      _placementStatus == PlacementOnboardingStatus.completed &&
      _profileSetupLookupGeneration == generation;

  Future<T> _enqueueStore<T>(
    Future<T> Function() operation, {
    Duration? timeout,
  }) {
    final completer = Completer<T>();
    _storeQueue = _storeQueue.then((_) async {
      try {
        final pending = operation();
        completer.complete(
          await (timeout == null ? pending : pending.timeout(timeout)),
        );
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void _setSession({
    required SessionStatus status,
    required PlacementOnboardingStatus placementStatus,
    required ProfileSetupStatus profileSetupStatus,
  }) {
    if (_status == status &&
        _placementStatus == placementStatus &&
        _profileSetupStatus == profileSetupStatus) {
      return;
    }
    _status = status;
    _placementStatus = placementStatus;
    _profileSetupStatus = profileSetupStatus;
    notifyListeners();
  }

  void _setProfileSetupStatus(ProfileSetupStatus value) {
    if (_profileSetupStatus == value) {
      return;
    }
    _profileSetupStatus = value;
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
