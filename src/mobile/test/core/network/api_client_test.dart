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
}
