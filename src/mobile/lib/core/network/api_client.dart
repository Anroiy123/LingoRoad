import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:lingoroad_mobile/core/config/app_config.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';

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
  Future<bool>? _refreshInFlight;

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
  }) =>
      _send(
        () => _httpClient.get(
          _config.resolve(path),
          headers: _headers(authenticated: authenticated),
        ),
        timeout: timeout,
        allowRefresh: authenticated,
      );

  Future<Object?> postJson(
    String path, {
    Object? body,
    bool authenticated = true,
    Duration? timeout,
  }) =>
      _send(
        () => _httpClient.post(
          _config.resolve(path),
          headers: _headers(
            authenticated: authenticated,
            hasJsonBody: true,
          ),
          body: jsonEncode(body),
        ),
        timeout: timeout,
        allowRefresh: authenticated,
      );

  Future<Object?> patchJson(
    String path, {
    Object? body,
    bool authenticated = true,
    Duration? timeout,
  }) =>
      _send(
        () => _httpClient.patch(
          _config.resolve(path),
          headers: _headers(authenticated: authenticated, hasJsonBody: true),
          body: jsonEncode(body),
        ),
        timeout: timeout,
        allowRefresh: authenticated,
      );

  Future<Object?> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required List<int> fileBytes,
    required String fileName,
    required String mimeType,
    Duration? timeout,
  }) =>
      _send(
        () async {
          final request = http.MultipartRequest('POST', _config.resolve(path));
          request.headers.addAll(_headers(authenticated: true));
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
      );

  Map<String, String> _headers({
    required bool authenticated,
    bool hasJsonBody = false,
  }) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (hasJsonBody) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
    }
    final token = _session.token;
    if (authenticated && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Object?> _send(
    Future<http.Response> Function() request, {
    Duration? timeout,
    bool allowRefresh = false,
  }) async {
    try {
      var response = await request().timeout(timeout ?? defaultTimeout);
      var body = _decode(response);
      if (response.statusCode == 401 &&
          allowRefresh &&
          _session.refreshToken != null &&
          await _refreshTokens()) {
        response = await request().timeout(timeout ?? defaultTimeout);
        body = _decode(response);
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body;
      }

      if (response.statusCode == 401) {
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
      throw ApiException(
        code: 'request_timeout',
        message: 'Kết nối quá thời gian chờ',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        code: 'network_unavailable',
        message: 'Không thể kết nối đến máy chủ',
        cause: error,
      );
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(
        code: 'network_unavailable',
        message: 'Không thể kết nối đến máy chủ',
        cause: error,
      );
    }
  }

  Future<bool> _refreshTokens() {
    final active = _refreshInFlight;
    if (active != null) return active;
    final future = _performRefresh();
    _refreshInFlight = future;
    future.whenComplete(() {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    });
    return future;
  }

  Future<bool> _performRefresh() async {
    final refreshToken = _session.refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await _httpClient
          .post(
            _config.resolve('/auth/refresh'),
            headers: _headers(authenticated: false, hasJsonBody: true),
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(defaultTimeout);
      final body = _decode(response);
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
      return _session.updateTokens(
        access,
        refresh,
        expectedRefreshToken: refreshToken,
      );
    } catch (_) {
      await _session.invalidate();
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
