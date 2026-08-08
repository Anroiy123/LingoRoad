import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:lingoroad_mobile/core/config/app_config.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  ApiClient({
    required AppConfig config,
    required SessionController session,
    http.Client? httpClient,
    this.defaultTimeout = const Duration(seconds: 15),
  })  : _config = config,
        _session = session,
        _httpClient = httpClient ?? http.Client();

  final AppConfig _config;
  final SessionController _session;
  final http.Client _httpClient;
  final Duration defaultTimeout;
  _RefreshFlight? _refreshInFlight;

  Uri resolveUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https')) {
      return uri;
    }
    return _config.resolve(value);
  }

  Future<Object?> get(
    String path, {
    bool authenticated = true,
    Duration? timeout,
  }) {
    final requestSession = _RequestSession.capture(_session, authenticated);
    return _send(
      (accessToken) => _httpClient.get(
        _config.resolve(path),
        headers: _headers(
          authenticated: authenticated,
          accessToken: accessToken,
        ),
      ),
      timeout: timeout,
      allowRefresh: authenticated,
      requestSession: requestSession,
    );
  }

  Future<Object?> postJson(
    String path, {
    Object? body,
    bool authenticated = true,
    Duration? timeout,
  }) {
    final requestSession = _RequestSession.capture(_session, authenticated);
    return _send(
      (accessToken) => _httpClient.post(
        _config.resolve(path),
        headers: _headers(
          authenticated: authenticated,
          hasJsonBody: true,
          accessToken: accessToken,
        ),
        body: jsonEncode(body),
      ),
      timeout: timeout,
      allowRefresh: authenticated,
      requestSession: requestSession,
    );
  }

  Future<Object?> patchJson(
    String path, {
    Object? body,
    bool authenticated = true,
    Duration? timeout,
  }) {
    final requestSession = _RequestSession.capture(_session, authenticated);
    return _send(
      (accessToken) => _httpClient.patch(
        _config.resolve(path),
        headers: _headers(
          authenticated: authenticated,
          hasJsonBody: true,
          accessToken: accessToken,
        ),
        body: jsonEncode(body),
      ),
      timeout: timeout,
      allowRefresh: authenticated,
      requestSession: requestSession,
    );
  }

  Future<Object?> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required List<int> fileBytes,
    required String fileName,
    required String mimeType,
    Duration? timeout,
  }) {
    final requestSession = _RequestSession.capture(_session, true);
    return _send(
      (accessToken) async {
        final request = http.MultipartRequest('POST', _config.resolve(path));
        request.headers.addAll(
          _headers(authenticated: true, accessToken: accessToken),
        );
        request.fields.addAll(fields);
        request.files.add(http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ));
        return http.Response.fromStream(await _httpClient.send(request));
      },
      timeout: timeout ?? const Duration(seconds: 45),
      allowRefresh: true,
      requestSession: requestSession,
    );
  }

  Map<String, String> _headers({
    required bool authenticated,
    bool hasJsonBody = false,
    String? accessToken,
  }) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (hasJsonBody) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
    }
    if (authenticated && accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  Future<Object?> _send(
    Future<http.Response> Function(String? accessToken) request, {
    Duration? timeout,
    bool allowRefresh = false,
    _RequestSession? requestSession,
  }) async {
    try {
      var activeSession = requestSession;
      var response = await request(activeSession?.accessToken)
          .timeout(timeout ?? defaultTimeout);

      if (response.request != null) {
        debugPrint(
            'DEBUG API: [${response.request!.method}] ${response.request!.url} -> Status ${response.statusCode}');
      }

      var body = _decode(response);
      final sessionForRefresh = activeSession;
      if (response.statusCode == 401 &&
          allowRefresh &&
          sessionForRefresh != null &&
          sessionForRefresh.matchesCurrent(_session) &&
          await _refreshTokens(sessionForRefresh) &&
          sessionForRefresh.hasSameGeneration(_session)) {
        final refreshedSession = _RequestSession.capture(_session, true);
        if (refreshedSession != null &&
            refreshedSession.matchesCurrent(_session)) {
          activeSession = refreshedSession;
          response = await request(refreshedSession.accessToken)
              .timeout(timeout ?? defaultTimeout);

          if (response.request != null) {
            debugPrint(
                'DEBUG API (Refreshed): [${response.request!.method}] ${response.request!.url} -> Status ${response.statusCode}');
          }

          body = _decode(response);
        }
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body;
      }

      if (response.statusCode == 401 &&
          activeSession != null &&
          activeSession.matchesCurrent(_session)) {
        await _session.invalidate();
      }

      final errorCode =
          body is Map<String, dynamic> ? body['error']?.toString() : null;
      throw ApiException(
        statusCode: response.statusCode,
        code: errorCode ?? 'http_${response.statusCode}',
        message: errorCode ?? 'Yêu cầu API không thành công',
      );
    } on TimeoutException catch (error) {
      debugPrint('DEBUG API Error: Timeout connecting to backend: $error');
      throw ApiException(
        code: 'request_timeout',
        message: 'Kết nối quá thời gian chờ',
        cause: error,
      );
    } on http.ClientException catch (error) {
      debugPrint(
          'DEBUG API Error: ClientException (Network/CORS/IP incorrect): $error');
      throw ApiException(
        code: 'network_unavailable',
        message: 'Không thể kết nối đến máy chủ',
        cause: error,
      );
    } on ApiException catch (error) {
      debugPrint(
          'DEBUG API Error: ApiException: [${error.code}] ${error.message}');
      rethrow;
    } catch (error) {
      debugPrint('DEBUG API Error: Unexpected network error: $error');
      throw ApiException(
        code: 'network_unavailable',
        message: 'Không thể kết nối đến máy chủ',
        cause: error,
      );
    }
  }

  Future<bool> _refreshTokens(_RequestSession requestSession) {
    final active = _refreshInFlight;
    if (active != null && active.matches(requestSession)) {
      return active.future;
    }
    final future = _performRefresh(requestSession);
    final flight = _RefreshFlight(requestSession, future);
    _refreshInFlight = flight;
    future.whenComplete(() {
      if (identical(_refreshInFlight, flight)) _refreshInFlight = null;
    });
    return future;
  }

  Future<bool> _performRefresh(_RequestSession requestSession) async {
    final refreshToken = requestSession.refreshToken;
    if (refreshToken == null || !requestSession.matchesCurrent(_session)) {
      return false;
    }
    try {
      final response = await _httpClient
          .post(
            _config.resolve('/auth/refresh'),
            headers: _headers(authenticated: false, hasJsonBody: true),
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(defaultTimeout);
      final body = _decode(response);
      if (!requestSession.matchesCurrent(_session)) {
        return false;
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body is! Map<String, dynamic>) {
        await _session.invalidate();
        return false;
      }
      final access = body['accessToken']?.toString();
      final refresh = body['refreshToken']?.toString();
      if (access == null ||
          access.isEmpty ||
          refresh == null ||
          refresh.isEmpty) {
        await _session.invalidate();
        return false;
      }
      return await _session.updateTokens(
        access,
        refresh,
        expectedRefreshToken: refreshToken,
      );
    } catch (_) {
      if (requestSession.matchesCurrent(_session)) {
        await _session.invalidate();
      }
      return false;
    }
  }

  Object? _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return null;
    }
    final text = utf8.decode(response.bodyBytes);
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.toLowerCase().contains('json')) {
      return text;
    }
    try {
      return jsonDecode(text);
    } on FormatException catch (error) {
      throw ApiException(
        statusCode: response.statusCode,
        code: 'malformed_response',
        message: 'Phản hồi máy chủ không hợp lệ',
        cause: error,
      );
    }
  }

  void close() => _httpClient.close();
}

class _RequestSession {
  const _RequestSession({
    required this.generation,
    required this.accessToken,
    required this.refreshToken,
  });

  static _RequestSession? capture(
    SessionController session,
    bool authenticated,
  ) {
    if (!authenticated) return null;
    return _RequestSession(
      generation: session.sessionGeneration,
      accessToken: session.token,
      refreshToken: session.refreshToken,
    );
  }

  final int generation;
  final String? accessToken;
  final String? refreshToken;

  bool matchesCurrent(SessionController session) =>
      session.status == SessionStatus.authenticated &&
      session.sessionGeneration == generation &&
      session.token == accessToken &&
      session.refreshToken == refreshToken;

  bool hasSameGeneration(SessionController session) =>
      session.status == SessionStatus.authenticated &&
      session.sessionGeneration == generation;
}

class _RefreshFlight {
  const _RefreshFlight(this.session, this.future);

  final _RequestSession session;
  final Future<bool> future;

  bool matches(_RequestSession other) =>
      session.generation == other.generation &&
      session.refreshToken == other.refreshToken;
}
