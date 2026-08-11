import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/app_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/domain/user_profile.dart';
import 'package:lingoroad_mobile/features/placement/data/placement_repository.dart';
import 'package:lingoroad_mobile/features/placement/domain/placement_models.dart';
import 'package:lingoroad_mobile/main.dart';
import 'package:lingoroad_mobile/widgets/brand_logo.dart';
import 'package:go_router/go_router.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_view_model.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';

import '../../helpers/widget_test_harness.dart';

AppLanguageProvider loadTestLanguageProvider() {
  final viContent = File('assets/translations/vi.json').readAsStringSync();
  final enContent = File('assets/translations/en.json').readAsStringSync();
  final viMap = json.decode(viContent) as Map<String, dynamic>;
  final enMap = json.decode(enContent) as Map<String, dynamic>;
  return AppLanguageProvider.test(
    translations: {
      AppLanguage.vi: viMap,
      AppLanguage.en: enMap,
    },
    currentLanguage: AppLanguage.vi,
  );
}

class RecoveringHangingClearSessionStore extends MemorySessionStore {
  RecoveringHangingClearSessionStore(super.token);

  bool hangClear = true;

  @override
  Future<void> clearToken() {
    if (hangClear) {
      return Completer<void>().future;
    }
    return super.clearToken();
  }
}

class FlowAuthRepository implements AuthRepository {
  @override Future<UserProfile> completeProfileSetup({required String name, required String targetCefr, required int dailyGoalMinutes}) => getProfile();
  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async =>
      const AuthTokens(accessToken: 'login-token', refreshToken: 'refresh');

  @override
  Future<AuthTokens> register({
    required String email,
    required String password,
    String? name,
  }) async =>
      const AuthTokens(accessToken: 'register-token', refreshToken: 'refresh');

  @override
  Future<UserProfile> getProfile() async => const UserProfile(
        id: 'user-id',
        email: 'test@gmail.com',
        name: 'Test User',
        targetCefr: 'B2',
        cefrLevel: 'A1',
        level: 12,
        badgesCount: 6,
      );

  @override
  Future<UserProfile> updateProfile(Map<String, Object?> values) =>
      getProfile();
  @override
  Future<void> changePassword(
      {required String currentPassword, required String newPassword}) async {}
  @override
  Future<void> logout(String? refreshToken) async {}
}

class AuthFlowPlacementRepository implements PlacementRepository {
  AuthFlowPlacementRepository({
    this.completed = false,
    this.pendingStatus,
  });

  final bool completed;
  final Future<bool>? pendingStatus;
  Object? statusError;
  int statusCalls = 0;

  @override
  Future<bool> isCompleted() async {
    statusCalls++;
    if (statusError != null) {
      throw statusError!;
    }
    final pending = pendingStatus;
    return pending == null ? completed : await pending;
  }

  @override
  Future<PlacementStart> start() =>
      throw UnimplementedError('Không gọi trong auth flow test');

  @override
  Future<PlacementStep> answer({
    required String sessionId,
    required String itemId,
    required String answer,
  }) =>
      throw UnimplementedError('Không gọi trong auth flow test');

  @override
  Future<PlacementResult> result(String sessionId) =>
      throw UnimplementedError('Không gọi trong auth flow test');
}

class TestAppFixture {
  TestAppFixture({
    required this.session,
    required this.authRepo,
    required this.placementRepo,
    String initialLocation = '/splash',
  }) {
    placementVM = PlacementViewModel(placementRepo);
    router = createAppRouter(
      session: session,
      placementViewModel: placementVM,
      initialLocation: initialLocation,
    );
    app = LingoRoadApp(
      routerConfig: router,
      sessionController: session,
      authRepository: authRepo,
      placementRepository: placementRepo,
      placementViewModel: placementVM,
      languageProvider: loadTestLanguageProvider(),
    );
  }

  final SessionController session;
  final AuthRepository authRepo;
  final PlacementRepository placementRepo;
  late final PlacementViewModel placementVM;
  late final GoRouter router;
  late final Widget app;

  void dispose() {
    router.dispose();
  }
}

void main() {
  testWidgets('checking hiển thị splash rồi unauthenticated về login',
      (tester) async {
    final session = SessionController(MemorySessionStore());
    final fixture = TestAppFixture(
      session: session,
      authRepo: FlowAuthRepository(),
      placementRepo: AuthFlowPlacementRepository(),
    );

    configureLingoRoadTestViewport(tester);
    await tester.pumpWidget(fixture.app);
    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.bySemanticsLabel('Logo LingoRoad'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await session.restore();
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    fixture.dispose();
  });

  testWidgets('authenticated vào placement và logout về login', (tester) async {
    final session = SessionController(MemorySessionStore('saved-token'));
    await session.restore();
    final fixture = TestAppFixture(
      session: session,
      authRepo: FlowAuthRepository(),
      placementRepo: AuthFlowPlacementRepository(),
    );

    configureLingoRoadTestViewport(tester);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra trình độ đầu vào'), findsOneWidget);

    await session.logout();
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('Kiểm tra trình độ đầu vào'), findsNothing);
    fixture.dispose();
  });

  testWidgets('restore giữ splash trong lúc chờ trạng thái rồi vào placement',
      (tester) async {
    final status = Completer<bool>();
    final session = SessionController(MemorySessionStore('saved-token'));
    final fixture = TestAppFixture(
      session: session,
      authRepo: FlowAuthRepository(),
      placementRepo: AuthFlowPlacementRepository(
        pendingStatus: status.future,
      ),
    );

    configureLingoRoadTestViewport(tester);
    await tester.pumpWidget(fixture.app);
    final restore = session.restore();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(session.placementStatus, PlacementOnboardingStatus.checking);

    status.complete(false);
    await restore;
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra trình độ đầu vào'), findsOneWidget);
    fixture.dispose();
  });

  testWidgets('lookup lỗi hiện retry và thử lại thành công vào placement',
      (tester) async {
    final repository = AuthFlowPlacementRepository()
      ..statusError = StateError('offline');
    final session = SessionController(MemorySessionStore('saved-token'));
    final fixture = TestAppFixture(
      session: session,
      authRepo: FlowAuthRepository(),
      placementRepo: repository,
    );

    configureLingoRoadTestViewport(tester);
    await tester.pumpWidget(fixture.app);
    await session.restore();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placement_status_error')), findsOneWidget);
    expect(repository.statusCalls, 2);

    repository.statusError = null;
    await tester.tap(find.byKey(const Key('placement_status_retry')));
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra trình độ đầu vào'), findsOneWidget);
    fixture.dispose();
  });

  testWidgets('lookup lỗi chỉ đăng xuất sau khi secure storage được xóa',
      (tester) async {
    final repository = AuthFlowPlacementRepository()
      ..statusError = StateError('offline');
    final store = RecoveringHangingClearSessionStore('saved-token');
    final session = SessionController(
      store,
      storeOperationTimeout: const Duration(milliseconds: 1),
    );
    final fixture = TestAppFixture(
      session: session,
      authRepo: FlowAuthRepository(),
      placementRepo: repository,
    );

    configureLingoRoadTestViewport(tester);
    await tester.pumpWidget(fixture.app);
    await session.restore();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placement_status_error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('placement_status_logout')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('placement_status_error')), findsOneWidget);
    expect(
      find.text('Không thể đăng xuất an toàn. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(session.status, SessionStatus.authenticated);
    expect(await store.readToken(), 'saved-token');

    store.hangClear = false;
    await tester.tap(find.byKey(const Key('placement_status_logout')));
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(session.status, SessionStatus.unauthenticated);
    expect(await store.readToken(), isNull);
    fixture.dispose();
  });

  testWidgets(
      'restore user đã hoàn thành placement vào home rồi logout về login',
      (tester) async {
    final session = SessionController(MemorySessionStore('saved-token'));
    final fixture = TestAppFixture(
      session: session,
      authRepo: FlowAuthRepository(),
      placementRepo: AuthFlowPlacementRepository(completed: true),
    );

    configureLingoRoadTestViewport(tester);
    await tester.pumpWidget(fixture.app);
    await session.restore();
    await tester.pumpAndSettle();
    expect(find.text('Học'), findsOneWidget);
    expect(session.placementStatus, PlacementOnboardingStatus.completed);

    await session.logout();
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(session.placementStatus, PlacementOnboardingStatus.unknown);
    fixture.dispose();
  });

  testWidgets('login validation và submit thành công', (tester) async {
    final session = SessionController(MemorySessionStore());
    await session.restore();
    final fixture = TestAppFixture(
      session: session,
      authRepo: FlowAuthRepository(),
      placementRepo: AuthFlowPlacementRepository(),
      initialLocation: '/login',
    );

    configureLingoRoadTestViewport(tester);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login_email')),
      'user@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra trình độ đầu vào'), findsOneWidget);
    fixture.dispose();
  });

  testWidgets('login user đã hoàn thành placement chuyển vào home',
      (tester) async {
    final session = SessionController(MemorySessionStore());
    await session.restore();
    final fixture = TestAppFixture(
      session: session,
      authRepo: FlowAuthRepository(),
      placementRepo: AuthFlowPlacementRepository(completed: true),
      initialLocation: '/login',
    );

    configureLingoRoadTestViewport(tester);
    await tester.pumpWidget(fixture.app);
    await tester.enterText(
      find.byKey(const Key('login_email')),
      'returning@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Học'), findsOneWidget);
    expect(find.text('Kiểm tra trình độ đầu vào'), findsNothing);
    fixture.dispose();
  });

  testWidgets('register thành công chuyển vào placement', (tester) async {
    final session = SessionController(MemorySessionStore());
    await session.restore();
    final fixture = TestAppFixture(
      session: session,
      authRepo: FlowAuthRepository(),
      placementRepo: AuthFlowPlacementRepository(),
      initialLocation: '/register',
    );

    configureLingoRoadTestViewport(tester);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('register_email')),
      'new@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register_password')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('register_confirm_password')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Kiểm tra trình độ đầu vào'), findsOneWidget);
    fixture.dispose();
  });

  testWidgets('chuyển sang Register và validate password', (tester) async {
    final session = SessionController(MemorySessionStore());
    await session.restore();
    final fixture = TestAppFixture(
      session: session,
      authRepo: FlowAuthRepository(),
      placementRepo: AuthFlowPlacementRepository(),
      initialLocation: '/login',
    );

    configureLingoRoadTestViewport(tester);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();
    final registerLink = find.text(
      'Chưa có tài khoản? Đăng ký',
      findRichText: true,
    );
    await tester.ensureVisible(registerLink);
    await tester.tap(registerLink);
    await tester.pumpAndSettle();
    expect(find.text('Tạo tài khoản'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('register_email')),
      'new@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register_password')),
      'short',
    );
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pump();
    expect(find.text('Mật khẩu cần ít nhất 8 ký tự'), findsOneWidget);
    fixture.dispose();
  });
}
