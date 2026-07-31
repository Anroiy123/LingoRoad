import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/domain/user_profile.dart';
import 'package:lingoroad_mobile/features/auth/presentation/auth_view_model.dart';

class FakeAuthRepository implements AuthRepository {
  String token = 'token';
  Object? error;
  Completer<String>? pending;
  String? receivedEmail;
  String? receivedName;
  int loginCalls = 0;

  @override
  Future<String> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    receivedEmail = email;
    if (error != null) {
      throw error!;
    }
    return pending?.future ?? token;
  }

  @override
  Future<String> register({
    required String email,
    required String password,
    String? name,
  }) async {
    receivedEmail = email;
    receivedName = name;
    if (error != null) {
      throw error!;
    }
    return token;
  }

  @override
  Future<UserProfile> getProfile() async {
    if (error != null) {
      throw error!;
    }
    return const UserProfile(
      id: 'user-id',
      email: 'test@gmail.com',
      name: 'Test User',
      targetCefr: 'B2',
      cefrLevel: 'A1',
      level: 12,
      badgesCount: 6,
    );
  }
}

void main() {
  late FakeAuthRepository repository;
  late SessionController session;
  late AuthViewModel viewModel;

  setUp(() async {
    repository = FakeAuthRepository();
    session = SessionController(MemorySessionStore());
    await session.restore();
    viewModel = AuthViewModel(
      authRepository: repository,
      sessionController: session,
    );
  });

  test('login chuẩn hóa email và authenticate session', () async {
    final success = await viewModel.login(
      email: '  USER@Example.COM ',
      password: 'password123',
    );

    expect(success, isTrue);
    expect(repository.receivedEmail, 'user@example.com');
    expect(session.status, SessionStatus.authenticated);
    expect(session.token, 'token');
  });

  test('register biến name trống thành null', () async {
    await viewModel.register(
      email: 'new@example.com',
      password: 'password123',
      name: '   ',
    );

    expect(repository.receivedName, isNull);
    expect(
      session.placementStatus,
      PlacementOnboardingStatus.required,
    );
  });

  test('map lỗi email_taken thành thông báo tiếng Việt', () async {
    repository.error = const ApiException(
      statusCode: 409,
      code: 'email_taken',
      message: 'email_taken',
    );

    final success = await viewModel.register(
      email: 'used@example.com',
      password: 'password123',
    );

    expect(success, isFalse);
    expect(viewModel.errorMessage, 'auth.error.email_taken');
  });

  test('chặn double submit', () async {
    repository.pending = Completer<String>();

    final first = viewModel.login(
      email: 'user@example.com',
      password: 'password123',
    );
    final second = await viewModel.login(
      email: 'user@example.com',
      password: 'password123',
    );

    expect(second, isFalse);
    expect(repository.loginCalls, 1);
    repository.pending!.complete('token');
    expect(await first, isTrue);
  });

  test('validation email và mật khẩu', () {
    expect(AuthViewModel.validateEmail('bad-email'), 'auth.validation.email_invalid');
    expect(AuthViewModel.validateEmail('a@b.com'), isNull);
    expect(
      AuthViewModel.validatePassword('short'),
      'auth.validation.password_too_short',
    );
    expect(AuthViewModel.validatePassword('password'), isNull);
  });
}
