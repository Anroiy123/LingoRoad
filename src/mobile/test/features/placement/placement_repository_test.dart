import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingoroad_mobile/core/config/app_config.dart';
import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/features/placement/data/placement_repository.dart';

void main() {
  Future<ApiPlacementRepository> createRepository(
    MockClient httpClient,
  ) async {
    final session = SessionController(MemorySessionStore('jwt-token'));
    await session.restore();
    final apiClient = ApiClient(
      config: AppConfig(apiBaseUrl: 'http://localhost:5000'),
      session: session,
      httpClient: httpClient,
    );
    return ApiPlacementRepository(apiClient);
  }

  test('start đọc session và câu hỏi đầu tiên', () async {
    final repository = await createRepository(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/placement/start');
        expect(request.headers['Authorization'], 'Bearer jwt-token');
        return http.Response(
          jsonEncode({
            'sessionId': 'session-1',
            'item': {
              'id': 'item-1',
              'type': 'multiple_choice',
              'stem': 'Choose the correct answer.',
              'options': ['A', 'B', 'C'],
              'audioUrl': '/audio/question.mp3',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final start = await repository.start();

    expect(start.sessionId, 'session-1');
    expect(start.item.id, 'item-1');
    expect(start.item.options, ['A', 'B', 'C']);
    expect(
      start.item.audioUrl,
      'http://localhost:5000/audio/question.mp3',
    );
  });

  test('answer gửi itemId, đáp án và đọc câu tiếp theo', () async {
    final repository = await createRepository(
      MockClient((request) async {
        expect(request.url.path, '/placement/session-1/answer');
        expect(jsonDecode(request.body), {
          'itemId': 'item-1',
          'answer': 'B',
        });
        return http.Response(
          jsonEncode({
            'done': false,
            'item': {
              'id': 'item-2',
              'type': 'multiple_choice',
              'stem': 'Next question',
              'options': ['True', 'False'],
              'audioUrl': null,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final step = await repository.answer(
      sessionId: 'session-1',
      itemId: 'item-1',
      answer: 'B',
    );

    expect(step.done, isFalse);
    expect(step.item?.id, 'item-2');
  });

  test('result đọc chỉ số CEFR cuối cùng', () async {
    final repository = await createRepository(
      MockClient((request) async => http.Response(
            jsonEncode({
              'theta': 0.72,
              'se': 0.31,
              'cefr': 'B1',
              'itemsAnswered': 12,
              'status': 'completed',
            }),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );

    final result = await repository.result('session-1');

    expect(result.cefr, 'B1');
    expect(result.itemsAnswered, 12);
    expect(result.se, 0.31);
  });

  test('response thiếu item thành malformed_response', () async {
    final repository = await createRepository(
      MockClient((_) async => http.Response(
            jsonEncode({'sessionId': 'session-1'}),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );

    await expectLater(
      repository.start(),
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
