import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoroad_mobile/core/config/app_config.dart';
import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';

void main() {
  ApiAuthRepository createRepository(MockClient httpClient) {
    final session = SessionController(MemorySessionStore());
    final apiClient = ApiClient(
      config: AppConfig(apiBaseUrl: 'http://localhost:5000'),
      session: session,
      httpClient: httpClient,
    );
    return ApiAuthRepository(apiClient);
  }

  test('login gửi payload chuẩn hóa và đọc token', () async {
    final repository = createRepository(
      MockClient((request) async {
        expect(request.url.path, '/auth/login');
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {
          'email': 'user@example.com',
          'password': 'password123',
        });
        return http.Response(
          jsonEncode({'token': 'jwt-token'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(
      await repository.login(
        email: 'user@example.com',
        password: 'password123',
      ),
      'jwt-token',
    );
  });

  test('register hỗ trợ name null và response 201', () async {
    final repository = createRepository(
      MockClient((request) async {
        expect(request.url.path, '/auth/register');
        expect(jsonDecode(request.body), {
          'email': 'new@example.com',
          'password': 'password123',
          'name': null,
        });
        return http.Response(
          jsonEncode({'token': 'new-token'}),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(
      await repository.register(
        email: 'new@example.com',
        password: 'password123',
      ),
      'new-token',
    );
  });

  test('response thiếu token thành malformed_response', () async {
    final repository = createRepository(
      MockClient(
        (_) async => http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      repository.login(email: 'user@example.com', password: 'password123'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'malformed_response',
        ),
      ),
    );
  });
}
