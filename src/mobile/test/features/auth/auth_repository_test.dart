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
import 'package:lingoroad_mobile/features/auth/domain/user_profile.dart';

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
          jsonEncode({'token': 'jwt-token', 'refreshToken': 'refresh-token'}),
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
      isA<AuthTokens>()
          .having((value) => value.accessToken, 'accessToken', 'jwt-token')
          .having(
              (value) => value.refreshToken, 'refreshToken', 'refresh-token'),
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
          jsonEncode({'token': 'new-token', 'refreshToken': 'new-refresh'}),
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
      isA<AuthTokens>()
          .having((value) => value.accessToken, 'accessToken', 'new-token')
          .having((value) => value.refreshToken, 'refreshToken', 'new-refresh'),
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

  test('profile server cũ thiếu profileSetupCompleted được xem là đã hoàn tất', () {
    final profile = UserProfile.fromJson({
      'id': 'id', 'email': 'a@example.com', 'name': 'A', 'targetCefr': 'B2',
    });
    expect(profile.profileSetupCompleted, isTrue);
  });
}
