import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';

abstract interface class AuthRepository {
  Future<String> login({
    required String email,
    required String password,
  });

  Future<String> register({
    required String email,
    required String password,
    String? name,
  });
}

class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/login',
      authenticated: false,
      body: {'email': email, 'password': password},
    );
    return _readToken(response);
  }

  @override
  Future<String> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/register',
      authenticated: false,
      body: {
        'email': email,
        'password': password,
        'name': name,
      },
    );
    return _readToken(response);
  }

  String _readToken(Object? response) {
    final token = response is Map<String, dynamic>
        ? response['token']?.toString().trim()
        : null;
    if (token == null || token.isEmpty) {
      throw const ApiException(
        code: 'malformed_response',
        message: 'Phản hồi xác thực không có token',
      );
    }
    return token;
  }
}
