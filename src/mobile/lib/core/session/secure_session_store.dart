import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';

class SecureSessionStore implements SessionStore {
  const SecureSessionStore([this._storage = const FlutterSecureStorage()]);

  static const tokenKey = 'lingoroad.access_token';

  final FlutterSecureStorage _storage;

  @override
  Future<void> clearToken() => _storage.delete(key: tokenKey);

  @override
  Future<String?> readToken() => _storage.read(key: tokenKey);

  @override
  Future<void> writeToken(String token) =>
      _storage.write(key: tokenKey, value: token);
}
