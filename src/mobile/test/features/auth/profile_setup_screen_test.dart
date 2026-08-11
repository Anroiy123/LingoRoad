import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/domain/user_profile.dart';
import 'package:lingoroad_mobile/features/auth/presentation/profile_setup_screen.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../helpers/widget_test_harness.dart';

class _ProfileSetupRepository implements AuthRepository {
  bool fail = true;
  int calls = 0;
  @override
  Future<UserProfile> completeProfileSetup({
    required String name,
    required String targetCefr,
    required int dailyGoalMinutes,
  }) async {
    calls++;
    if (fail) throw StateError('offline');
    return const UserProfile(
      id: 'u',
      email: 'u@example.com',
      name: 'Learner',
      targetCefr: 'B1',
      cefrLevel: 'A1',
      level: 1,
      badgesCount: 0,
      profileSetupCompleted: true,
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
  @override
  Future<UserProfile> getProfile() => throw UnimplementedError();
  @override
  Future<AuthTokens> login({required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> logout(String? refreshToken) async {}
  @override
  Future<AuthTokens> register({
    required String email,
    required String password,
    String? name,
  }) => throw UnimplementedError();
  @override
  Future<UserProfile> updateProfile(Map<String, Object?> values) =>
      throw UnimplementedError();
}

class _FailingClearSessionStore extends MemorySessionStore {
  _FailingClearSessionStore(super.token);

  @override
  Future<void> clearToken() => Future<void>.error(StateError('locked'));
}

Future<void> _pumpStatusError(WidgetTester tester, SessionController session) =>
    pumpWidgetWithLingoRoadScreenUtil(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<AppLanguageProvider>.value(
            value: AppLanguageProvider.empty(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProfileSetupStatusErrorScreen(),
        ),
      ),
    );

void main() {
  testWidgets('giữ giá trị sau lỗi và cho phép thử lại', (tester) async {
    final repository = _ProfileSetupRepository();
    final session = SessionController(MemorySessionStore());
    await session.authenticate('token', checkPlacement: false);
    session.markPlacementCompleted();
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      MultiProvider(
        providers: [
          Provider<AuthRepository>.value(value: repository),
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<AppLanguageProvider>.value(
            value: AppLanguageProvider.empty(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProfileSetupScreen(),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('profile_setup_name')),
      'Learner',
    );
    await tester.tap(find.byKey(const Key('profile_setup_submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_setup_error')), findsOneWidget);
    expect(find.text('Learner'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.byKey(const Key('profile_setup_submit')));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(session.profileSetupStatus, ProfileSetupStatus.completed);
  });

  testWidgets('status error retry reloads profile setup completion', (
    tester,
  ) async {
    var fail = true;
    final session = SessionController(MemorySessionStore());
    await session.authenticate('token', checkPlacement: false);
    session.configureProfileSetupStatusLoader(() async {
      if (fail) throw StateError('offline');
      return true;
    });
    await session.markPlacementCompleted();
    expect(session.profileSetupStatus, ProfileSetupStatus.error);

    await _pumpStatusError(tester, session);
    fail = false;
    await tester.tap(find.byKey(const Key('profile_setup_status_retry')));
    await tester.pumpAndSettle();

    expect(session.profileSetupStatus, ProfileSetupStatus.completed);
  });

  testWidgets('status error reports logout failure and keeps session', (
    tester,
  ) async {
    final session = SessionController(
      _FailingClearSessionStore('token'),
      storeOperationTimeout: const Duration(milliseconds: 50),
    );
    session.configurePlacementStatusLoader(() async => true);
    session.configureProfileSetupStatusLoader(
      () => Future<bool>.error(StateError('offline')),
    );
    await session.restore();
    expect(session.profileSetupStatus, ProfileSetupStatus.error);

    await _pumpStatusError(tester, session);
    await tester.tap(find.byKey(const Key('profile_setup_status_logout')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(session.status, SessionStatus.authenticated);
    expect(session.profileSetupStatus, ProfileSetupStatus.error);
  });

  testWidgets('completed profile setup resumes as completed after restart', (
    tester,
  ) async {
    final store = MemorySessionStore('token');
    final repository = _ProfileSetupRepository()..fail = false;
    final firstSession = SessionController(store);
    await firstSession.authenticate('token', checkPlacement: false);
    firstSession.configureProfileSetupStatusLoader(() async => false);
    await firstSession.markPlacementCompleted();
    expect(firstSession.profileSetupStatus, ProfileSetupStatus.required);

    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      MultiProvider(
        providers: [
          Provider<AuthRepository>.value(value: repository),
          ChangeNotifierProvider<SessionController>.value(value: firstSession),
          ChangeNotifierProvider<AppLanguageProvider>.value(
            value: AppLanguageProvider.empty(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProfileSetupScreen(),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('profile_setup_name')),
      'Learner',
    );
    await tester.tap(find.byKey(const Key('profile_setup_submit')));
    await tester.pumpAndSettle();
    expect(firstSession.profileSetupStatus, ProfileSetupStatus.completed);

    final restartedSession = SessionController(store);
    restartedSession.configurePlacementStatusLoader(() async => true);
    restartedSession.configureProfileSetupStatusLoader(() async => true);
    await restartedSession.restore();

    expect(restartedSession.status, SessionStatus.authenticated);
    expect(
      restartedSession.placementStatus,
      PlacementOnboardingStatus.completed,
    );
    expect(restartedSession.profileSetupStatus, ProfileSetupStatus.completed);
  });
}
