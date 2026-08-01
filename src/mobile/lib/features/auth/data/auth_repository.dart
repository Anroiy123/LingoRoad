import 'package:lingoroad_mobile/core/network/api_client.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/features/auth/domain/user_profile.dart';

abstract interface class AuthRepository {
  Future<AuthTokens> login({
    required String email,
    required String password,
  });

  Future<AuthTokens> register({
    required String email,
    required String password,
    String? name,
  });

  Future<UserProfile> getProfile();
  Future<UserProfile> updateProfile(Map<String, Object?> values);
  Future<void> changePassword(
      {required String currentPassword, required String newPassword});
  Future<void> logout(String? refreshToken);
}

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;
}

class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<AuthTokens> login({
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
  Future<AuthTokens> register({
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

  @override
  Future<UserProfile> getProfile() async {
    final response = await _apiClient.get('/auth/me');
    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        code: 'malformed_response',
        message: 'Phản hồi thông tin cá nhân không hợp lệ',
      );
    }
    return UserProfile.fromJson(response);
  }

  @override
  Future<UserProfile> updateProfile(Map<String, Object?> values) async {
    final response = await _apiClient.patchJson('/auth/me', body: values);
    if (response is! Map<String, dynamic>) {
      throw const ApiException(
          code: 'malformed_response',
          message: 'Phản hồi thông tin cá nhân không hợp lệ');
    }
    return UserProfile.fromJson(response);
  }

  @override
  Future<void> changePassword(
          {required String currentPassword, required String newPassword}) =>
      _apiClient.postJson('/auth/change-password', body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

  @override
  Future<void> logout(String? refreshToken) =>
      _apiClient.postJson('/auth/logout',
          body: {'refreshToken': refreshToken}, authenticated: false);

  AuthTokens _readToken(Object? response) {
    final access = response is Map<String, dynamic>
        ? (response['accessToken'] ?? response['token'])?.toString().trim()
        : null;
    final refresh = response is Map<String, dynamic>
        ? response['refreshToken']?.toString().trim()
        : null;
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      throw const ApiException(
        code: 'malformed_response',
        message: 'Phản hồi xác thực không có token',
      );
    }
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }
}
