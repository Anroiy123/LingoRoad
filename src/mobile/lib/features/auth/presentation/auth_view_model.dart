import 'package:flutter/foundation.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    required AuthRepository authRepository,
    required SessionController sessionController,
  })  : _authRepository = authRepository,
        _sessionController = sessionController;

  final AuthRepository _authRepository;
  final SessionController _sessionController;

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<bool> login({
    required String email,
    required String password,
  }) =>
      _submit(
        () => _authRepository.login(
          email: normalizeEmail(email),
          password: password,
        ),
        checkPlacement: true,
      );

  Future<bool> register({
    required String email,
    required String password,
    String? name,
  }) =>
      _submit(
        () => _authRepository.register(
          email: normalizeEmail(email),
          password: password,
          name: _normalizeOptional(name),
        ),
        checkPlacement: false,
      );

  Future<bool> _submit(
    Future<String> Function() request, {
    required bool checkPlacement,
  }) async {
    if (_isSubmitting) {
      return false;
    }
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final token = await request();
      await _sessionController.authenticate(
        token,
        checkPlacement: checkPlacement,
      );
      return true;
    } on ApiException catch (error) {
      _errorMessage = messageFor(error);
      return false;
    } catch (_) {
      _errorMessage = 'auth.error.generic';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String? validateEmail(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'auth.validation.email_empty';
    }
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized);
    return valid ? null : 'auth.validation.email_invalid';
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'auth.validation.password_empty';
    }
    return value.length >= 8 ? null : 'auth.validation.password_too_short';
  }

  static String messageFor(ApiException error) {
    return switch (error.code) {
      'password_too_short' => 'auth.validation.password_too_short',
      'email_taken' => 'auth.error.email_taken',
      'http_401' => 'auth.error.invalid_credentials',
      'network_unavailable' => 'auth.error.network_unavailable',
      'request_timeout' => 'auth.error.request_timeout',
      _ => 'auth.error.generic',
    };
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
