import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoroad_mobile/core/config/app_config.dart';
import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/features/learning_path/data/learning_path_repository.dart';

void main() {
  Future<ApiLearningPathRepository> createRepository(
    MockClient httpClient,
  ) async {
    final session = SessionController(MemorySessionStore('jwt-token'));
    await session.restore();
    return ApiLearningPathRepository(
      ApiClient(
        config: AppConfig(apiBaseUrl: 'http://localhost:5000'),
        session: session,
        httpClient: httpClient,
      ),
    );
  }

  test('gọi GET /path với limit mặc định và đọc danh sách', () async {
    final repository = await createRepository(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/path');
        expect(request.url.queryParameters['limit'], '10');
        expect(request.headers['Authorization'], 'Bearer jwt-token');
        return http.Response(
          jsonEncode([
            {
              'code': 'listening.main-idea',
              'name': 'Main idea',
              'nameVi': 'Ý chính',
              'cefr': 'A2',
              'mastery': 0.2,
              'reason': 'below_threshold',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final steps = await repository.fetch();

    expect(steps, hasLength(1));
    expect(steps.single.code, 'listening.main-idea');
  });

  test('chấp nhận danh sách trống', () async {
    final repository = await createRepository(
      MockClient((_) async => http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
          )),
    );

    expect(await repository.fetch(), isEmpty);
  });

  test('response không phải danh sách thành malformed_response', () async {
    final repository = await createRepository(
      MockClient((_) async => http.Response(
            jsonEncode({'items': []}),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );

    await expectLater(
      repository.fetch(),
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
