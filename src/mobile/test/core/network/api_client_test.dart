import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoroad_mobile/core/config/app_config.dart';
import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';

void main() {
  late SessionController session;

  setUp(() async {
    session = SessionController(MemorySessionStore('jwt-token'));
    await session.restore();
  });

  test('gắn bearer token và đọc JSON thành công', () async {
    final client = ApiClient(
      config: AppConfig(apiBaseUrl: 'http://localhost:5000'),
      session: session,
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer jwt-token');
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(await client.get('/protected'), {'ok': true});
  });

  test('đọc plain text health response', () async {
    final client = ApiClient(
      config: AppConfig(apiBaseUrl: 'http://localhost:5000'),
      session: session,
      httpClient: MockClient((_) async => http.Response('ok', 200)),
    );

    expect(await client.get('/health', authenticated: false), 'ok');
  });

  test('multipart gắn bearer, MIME và fields cho speaking', () async {
    String? authorization;
    String? contentType;
    String? requestBody;
    final client = ApiClient(
      config: AppConfig(apiBaseUrl: 'http://localhost:5000'),
      session: session,
      httpClient: MockClient((request) async {
        authorization = request.headers['Authorization'];
        contentType = request.headers['content-type'];
        requestBody = latin1.decode(request.bodyBytes);
        return http.Response(
          jsonEncode({'total': .9}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(
      await client.postMultipart(
        '/speaking/attempts',
        fields: {'promptText': 'Read this sentence'},
        fileField: 'audio',
        fileBytes: [1, 2, 3],
        fileName: 'speaking.wav',
        mimeType: 'audio/wav',
      ),
      {'total': .9},
    );
    expect(authorization, 'Bearer jwt-token');
    expect(contentType, contains('multipart/form-data'));
    expect(requestBody, contains('promptText'));
    expect(requestBody, contains('Read this sentence'));
    expect(requestBody, contains('content-type: audio/wav'));
  });

  test('401 xóa session', () async {
    final client = ApiClient(
      config: AppConfig(apiBaseUrl: 'http://localhost:5000'),
      session: session,
      httpClient: MockClient((_) async => http.Response('', 401)),
    );

    await expectLater(
      client.get('/protected'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(session.status, SessionStatus.unauthenticated);
    expect(session.token, isNull);
  });

  test('401 từ request phiên cũ không thể logout phiên mới', () async {
    session = SessionController(MemorySessionStore('old-token', 'old-refresh'));
    await session.restore();
    final response = Completer<http.Response>();
    final requestStarted = Completer<void>();
    final client = ApiClient(
      config: AppConfig(apiBaseUrl: 'http://localhost:5000'),
      session: session,
      httpClient: MockClient((request) {
        expect(request.headers['Authorization'], 'Bearer old-token');
        requestStarted.complete();
        return response.future;
      }),
    );

    final pending = client.get('/protected');
    await requestStarted.future;
    await session.authenticate(
      'new-token',
      refreshToken: 'new-refresh',
      checkPlacement: false,
    );
    response.complete(http.Response('', 401));

    await expectLater(
      pending,
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(session.status, SessionStatus.authenticated);
    expect(session.token, 'new-token');
    expect(session.refreshToken, 'new-refresh');
  });

  test('refresh lỗi từ phiên cũ không thể logout phiên mới', () async {
    session = SessionController(MemorySessionStore('old-token', 'old-refresh'));
    await session.restore();
    final refreshResponse = Completer<http.Response>();
    final refreshStarted = Completer<void>();
    final client = ApiClient(
      config: AppConfig(apiBaseUrl: 'http://localhost:5000'),
      session: session,
      httpClient: MockClient((request) {
        if (request.url.path == '/protected') {
          return Future.value(http.Response('', 401));
        }
        if (request.url.path == '/auth/refresh') {
          refreshStarted.complete();
          return refreshResponse.future;
        }
        throw StateError('Unexpected request: ${request.url}');
      }),
    );

    final pending = client.get('/protected');
    await refreshStarted.future;
    await session.authenticate(
      'new-token',
      refreshToken: 'new-refresh',
      checkPlacement: false,
    );
    refreshResponse.complete(http.Response('', 401));

    await expectLater(
      pending,
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(session.status, SessionStatus.authenticated);
    expect(session.token, 'new-token');
    expect(session.refreshToken, 'new-refresh');
  });

  test('parse error code từ JSON', () async {
    final client = ApiClient(
      config: AppConfig(apiBaseUrl: 'http://localhost:5000'),
      session: session,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({'error': 'email_taken'}),
          409,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      client.postJson('/auth/register', authenticated: false, body: {}),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'email_taken',
        ),
      ),
    );
  });

  test('timeout được map thành request_timeout', () async {
    final client = ApiClient(
      config: AppConfig(apiBaseUrl: 'http://localhost:5000'),
      session: session,
      defaultTimeout: const Duration(milliseconds: 1),
      httpClient: MockClient((_) => Completer<http.Response>().future),
    );

    await expectLater(
      client.get('/slow'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'request_timeout',
        ),
      ),
    );
  });

  test('hai 401 đồng thời chỉ xoay refresh token một lần', () async {
    session =
        SessionController(MemorySessionStore('expired-token', 'refresh-1'));
    await session.restore();
    var expiredCalls = 0;
    var refreshCalls = 0;
    final bothExpired = Completer<void>();
    final client = ApiClient(
      config: AppConfig(apiBaseUrl: 'http://localhost:5000'),
      session: session,
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/refresh') {
          refreshCalls++;
          await bothExpired.future;
          return http.Response(
            jsonEncode({
              'accessToken': 'access-2',
              'refreshToken': 'refresh-2',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.headers['Authorization'] == 'Bearer access-2') {
          return http.Response(
            jsonEncode({'ok': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        expiredCalls++;
        if (expiredCalls == 2) bothExpired.complete();
        return http.Response('', 401);
      }),
    );

    final results = await Future.wait([
      client.get('/first'),
      client.get('/second'),
    ]);
    expect(results, [
      {'ok': true},
      {'ok': true},
    ]);
    expect(refreshCalls, 1);
    expect(session.token, 'access-2');
    expect(session.refreshToken, 'refresh-2');
  });
}
