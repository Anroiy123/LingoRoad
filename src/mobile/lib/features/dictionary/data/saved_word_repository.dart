import 'package:lingoroad_mobile/core/network/api_client.dart';

abstract interface class SavedWordRepository {
  Future<void> save(String skillCode, String word, String definition);
}

class ApiSavedWordRepository implements SavedWordRepository {
  const ApiSavedWordRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> save(String skillCode, String word, String definition) async {
    await _apiClient.postJson('/words', body: {
      'skillCode': skillCode,
      'word': word,
      'definition': definition,
    });
  }
}
