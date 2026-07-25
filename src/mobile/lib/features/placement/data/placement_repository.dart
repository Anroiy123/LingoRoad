import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/features/placement/domain/placement_models.dart';

abstract interface class PlacementRepository {
  Future<PlacementStart> start();

  Future<PlacementStep> answer({
    required String sessionId,
    required String itemId,
    required String answer,
  });

  Future<PlacementResult> result(String sessionId);
}

class ApiPlacementRepository implements PlacementRepository {
  const ApiPlacementRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<PlacementStart> start() async {
    final response = await _apiClient.postJson('/placement/start');
    final start = PlacementStart.fromJson(response);
    return PlacementStart(
      sessionId: start.sessionId,
      item: _resolveAudioUrl(start.item),
    );
  }

  @override
  Future<PlacementStep> answer({
    required String sessionId,
    required String itemId,
    required String answer,
  }) async {
    final response = await _apiClient.postJson(
      '/placement/$sessionId/answer',
      body: {'itemId': itemId, 'answer': answer},
    );
    final step = PlacementStep.fromJson(response);
    return PlacementStep(
      done: step.done,
      item: step.item == null ? null : _resolveAudioUrl(step.item!),
      theta: step.theta,
      se: step.se,
      cefr: step.cefr,
    );
  }

  @override
  Future<PlacementResult> result(String sessionId) async {
    final response = await _apiClient.get('/placement/$sessionId/result');
    return PlacementResult.fromJson(response);
  }

  PlacementItem _resolveAudioUrl(PlacementItem item) {
    final audioUrl = item.audioUrl;
    if (audioUrl == null) {
      return item;
    }
    return PlacementItem(
      id: item.id,
      type: item.type,
      stem: item.stem,
      options: item.options,
      audioUrl: _apiClient.resolveUrl(audioUrl).toString(),
    );
  }
}
