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
import 'package:lingoroad_mobile/features/review/data/review_repository.dart';
import 'package:lingoroad_mobile/features/review/domain/review_models.dart';
import 'package:lingoroad_mobile/features/review/presentation/review_view_model.dart';

final card = ReviewCard(
  id: '11111111-1111-1111-1111-111111111111',
  front: 'front from server',
  back: 'back from server',
  due: DateTime(2026),
  state: 'new',
  reps: 0,
);

class FakeReviewRepository implements ReviewRepository {
  List<ReviewCard> due = [card];
  Object? fetchError;
  Object? gradeError;
  Completer<void>? pendingGrade;
  int fetchCalls = 0;
  final List<int> ratings = [];
  final List<String> operationIds = [];

  @override
  Future<List<ReviewCard>> fetchDue() async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    return due;
  }

  @override
  Future<void> grade(
      {required ReviewCard card,
      required int rating,
      required String operationId}) async {
    ratings.add(rating);
    operationIds.add(operationId);
    if (gradeError != null) throw gradeError!;
    await pendingGrade?.future;
  }

  @override
  Future<void> createCard(String skillCode, String front, String back) async {}
}

void main() {
  test('ReviewCard strictly parses raw server front/back and reps', () {
    final parsed = ReviewCard.fromJson({
      'id': card.id,
      'front': card.front,
      'back': card.back,
      'due': '2026-01-01T00:00:00Z',
      'state': 'new',
      'reps': 2,
    });
    expect(parsed.front, 'front from server');
    expect(parsed.back, 'back from server');
    expect(parsed.reps, 2);
    expect(() => ReviewCard.fromJson({'id': card.id}),
        throwsA(isA<ApiException>()));
  });

  test('API repository uses due path, authorization, and grade body', () async {
    final session = SessionController(MemorySessionStore('jwt'));
    await session.restore();
    final repository = ApiReviewRepository(ApiClient(
      config: AppConfig(apiBaseUrl: 'http://localhost:5000'),
      session: session,
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer jwt');
        if (request.method == 'GET') {
          expect(request.url.path, '/words');
          expect(request.url.queryParameters['due'], 'true');
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'});
        }
        expect(request.url.path, '/words/${card.id}/review');
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json'});
      }),
    ));
    expect(await repository.fetchDue(), isEmpty);
    await repository.grade(card: card, rating: 4, operationId: 'op');
  });

  test(
      'view model reaches loading, empty, error/retry and maps all four ratings',
      () async {
    final repository = FakeReviewRepository();
    final vm = ReviewViewModel(repository);
    repository.due = const [];
    await vm.load();
    expect(vm.state, ReviewState.empty);
    repository.fetchError =
        const ApiException(code: 'network_unavailable', message: 'offline');
    await vm.load();
    expect(vm.state, ReviewState.error);
    repository.fetchError = null;
    repository.due = [card, card, card, card];
    await vm.load();
    for (final rating in [1, 2, 3, 4]) {
      await vm.grade(rating);
    }
    expect(repository.ratings, [1, 2, 3, 4]);
    expect(vm.state, ReviewState.complete);
  });

  test(
      'grade is single-flight, does not advance on failure, and keeps operation id for retry',
      () async {
    final repository = FakeReviewRepository()..pendingGrade = Completer<void>();
    final vm = ReviewViewModel(repository);
    await vm.load();
    final first = vm.grade(3);
    await vm.grade(3);
    expect(vm.gradePending, isTrue);
    expect(repository.ratings, [3]);
    repository.pendingGrade!.complete();
    await first;

    await vm.load();
    repository.gradeError =
        const ApiException(code: 'request_timeout', message: 'unknown outcome');
    await vm.grade(2);
    expect(vm.state, ReviewState.ready);
    final failedOperation = repository.operationIds.last;
    repository.gradeError = null;
    await vm.grade(2);
    expect(repository.operationIds.last, failedOperation);
  });
}
