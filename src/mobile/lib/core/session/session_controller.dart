import 'package:flutter/foundation.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';

enum SessionStatus { checking, unauthenticated, authenticated }

class SessionController extends ChangeNotifier {
  SessionController(this._store);

  final SessionStore _store;
  SessionStatus _status = SessionStatus.checking;
  String? _token;

  SessionStatus get status => _status;
  String? get token => _token;

  Future<void> restore() async {
    try {
      final stored = (await _store.readToken())?.trim();
      _token = stored == null || stored.isEmpty ? null : stored;
    } catch (_) {
      _token = null;
    }
    _setStatus(
      _token == null
          ? SessionStatus.unauthenticated
          : SessionStatus.authenticated,
    );
  }

  Future<void> authenticate(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(token, 'token', 'Token không được để trống');
    }
    await _store.writeToken(normalized);
    _token = normalized;
    _setStatus(SessionStatus.authenticated);
  }

  Future<void> logout() async {
    await _store.clearToken();
    _token = null;
    _setStatus(SessionStatus.unauthenticated);
  }

  Future<void> invalidate() => logout();

  void _setStatus(SessionStatus value) {
    if (_status == value) {
      return;
    }
    _status = value;
    notifyListeners();
  }
}
