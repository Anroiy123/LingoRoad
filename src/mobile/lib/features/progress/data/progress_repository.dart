import 'dart:async';
import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/progress/domain/progress_models.dart';

abstract interface class ProgressRepository {
  Future<List<SkillCatalogItem>> skills();
  Future<List<MasteryRow>> mastery();
}

class ApiProgressRepository implements ProgressRepository {
  const ApiProgressRepository(this._client);
  final ApiClient _client;
  @override
  Future<List<SkillCatalogItem>> skills() async {
    final v = await _client.get('/skills', authenticated: false);
    if (v is! List) {
      throw const ApiException(
          code: 'malformed_response', message: 'Phản hồi tiến độ không hợp lệ');
    }
    return v.map(SkillCatalogItem.fromJson).toList(growable: false);
  }

  @override
  Future<List<MasteryRow>> mastery() async {
    final v = await _client.get('/mastery');
    if (v is! List) {
      throw const ApiException(
          code: 'malformed_response', message: 'Phản hồi tiến độ không hợp lệ');
    }
    return v.map(MasteryRow.fromJson).toList(growable: false);
  }
}
