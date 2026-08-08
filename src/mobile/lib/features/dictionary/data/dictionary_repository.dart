import 'package:lingoroad_mobile/core/network/api_client.dart';

abstract interface class DictionaryRepository {
  Future<String> lookup(String word);
}

class ApiDictionaryRepository implements DictionaryRepository {
  const ApiDictionaryRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<String> lookup(String word) async {
    final response = await _apiClient.postJson(
      '/dictionary/lookup',
      body: {'word': word},
    );
    final data = response as Map<String, dynamic>;
    return data['definition'] as String;
  }
}
