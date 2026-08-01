import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/dashboard/domain/dashboard_models.dart';

abstract interface class DashboardRepository {
  Future<DashboardData> dashboard();
  Future<List<QuestData>> quests();
}

class ApiDashboardRepository implements DashboardRepository {
  const ApiDashboardRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DashboardData> dashboard() async =>
      DashboardData.fromJson(await _apiClient.get('/dashboard'));

  @override
  Future<List<QuestData>> quests() async {
    final response = await _apiClient.get('/quests');
    if (response is! List) {
      throw const ApiException(
        code: 'malformed_response',
        message: 'Phản hồi nhiệm vụ không hợp lệ',
      );
    }
    return response.map(QuestData.fromJson).toList(growable: false);
  }
}
