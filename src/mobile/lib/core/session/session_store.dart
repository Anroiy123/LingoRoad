abstract interface class SessionStore {
  Future<String?> readToken();

  Future<void> writeToken(String token);

  Future<void> clearToken();
}

abstract interface class RefreshSessionStore {
  Future<String?> readRefreshToken();
  Future<void> writeRefreshToken(String token);
  Future<void> clearRefreshToken();
}

class MemorySessionStore implements SessionStore, RefreshSessionStore {
  MemorySessionStore([this._token, this._refreshToken]);

  String? _token;
  String? _refreshToken;

  @override
  Future<void> clearToken() async {
    _token = null;
  }

  @override
  Future<void> clearRefreshToken() async => _refreshToken = null;

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<void> writeRefreshToken(String token) async => _refreshToken = token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async {
    _token = token;
  }
}
