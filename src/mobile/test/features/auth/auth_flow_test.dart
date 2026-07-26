import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/app_router.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/placement/data/placement_repository.dart';
import 'package:lingoroad_mobile/features/placement/domain/placement_models.dart';
import 'package:lingoroad_mobile/main.dart';
import 'package:lingoroad_mobile/widgets/brand_logo.dart';

class FlowAuthRepository implements AuthRepository {
  @override
  Future<String> login({
    required String email,
    required String password,
  }) async =>
      'login-token';

  @override
  Future<String> register({
    required String email,
    required String password,
    String? name,
  }) async =>
      'register-token';
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

void main() {
  testWidgets('checking hiển thị splash rồi unauthenticated về login',
      (tester) async {
    final session = SessionController(MemorySessionStore());
    final router = createAppRouter(
      session: session,
      authRepository: FlowAuthRepository(),
      placementRepository: AuthFlowPlacementRepository(),
    );

    await tester.pumpWidget(LingoRoadApp(routerConfig: router));
    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.bySemanticsLabel('Logo LingoRoad'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await session.restore();
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    router.dispose();
  });

  testWidgets('authenticated vào placement và logout về login', (tester) async {
    final session = SessionController(MemorySessionStore('saved-token'));
    await session.restore();
    final router = createAppRouter(
      session: session,
      authRepository: FlowAuthRepository(),
      placementRepository: AuthFlowPlacementRepository(),
    );

    await tester.pumpWidget(LingoRoadApp(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra trình độ đầu vào'), findsOneWidget);

    await session.logout();
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('Kiểm tra trình độ đầu vào'), findsNothing);
    router.dispose();
  });

  testWidgets('restore giữ splash trong lúc chờ trạng thái rồi vào placement',
      (tester) async {
    final status = Completer<bool>();
    final session = SessionController(MemorySessionStore('saved-token'));
    final router = createAppRouter(
      session: session,
      authRepository: FlowAuthRepository(),
      placementRepository: AuthFlowPlacementRepository(
        pendingStatus: status.future,
      ),
    );

    await tester.pumpWidget(LingoRoadApp(routerConfig: router));
    final restore = session.restore();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(session.placementStatus, PlacementOnboardingStatus.checking);

    status.complete(false);
    await restore;
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra trình độ đầu vào'), findsOneWidget);
    router.dispose();
  });

  testWidgets('lookup lỗi hiện retry và thử lại thành công vào placement',
      (tester) async {
    final repository = AuthFlowPlacementRepository()
      ..statusError = StateError('offline');
    final session = SessionController(MemorySessionStore('saved-token'));
    final router = createAppRouter(
      session: session,
      authRepository: FlowAuthRepository(),
      placementRepository: repository,
    );

    await tester.pumpWidget(LingoRoadApp(routerConfig: router));
    await session.restore();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placement_status_error')), findsOneWidget);
    expect(repository.statusCalls, 2);

    repository.statusError = null;
    await tester.tap(find.byKey(const Key('placement_status_retry')));
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra trình độ đầu vào'), findsOneWidget);
    router.dispose();
  });

  testWidgets(
      'restore user đã hoàn thành placement vào home rồi logout về login',
      (tester) async {
    final session = SessionController(MemorySessionStore('saved-token'));
    final router = createAppRouter(
      session: session,
      authRepository: FlowAuthRepository(),
      placementRepository: AuthFlowPlacementRepository(completed: true),
    );

    await tester.pumpWidget(LingoRoadApp(routerConfig: router));
    await session.restore();
    await tester.pumpAndSettle();
    expect(find.text('Học'), findsOneWidget);
    expect(session.placementStatus, PlacementOnboardingStatus.completed);

    await session.logout();
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(session.placementStatus, PlacementOnboardingStatus.unknown);
    router.dispose();
  });

  testWidgets('login validation và submit thành công', (tester) async {
    final session = SessionController(MemorySessionStore());
    await session.restore();
    final router = createAppRouter(
      session: session,
      authRepository: FlowAuthRepository(),
      placementRepository: AuthFlowPlacementRepository(),
      initialLocation: '/login',
    );

    await tester.pumpWidget(LingoRoadApp(routerConfig: router));
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
    router.dispose();
  });

  testWidgets('login user đã hoàn thành placement chuyển vào home',
      (tester) async {
    final session = SessionController(MemorySessionStore());
    await session.restore();
    final router = createAppRouter(
      session: session,
      authRepository: FlowAuthRepository(),
      placementRepository: AuthFlowPlacementRepository(completed: true),
      initialLocation: '/login',
    );

    await tester.pumpWidget(LingoRoadApp(routerConfig: router));
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
    router.dispose();
  });

  testWidgets('register thành công chuyển vào placement', (tester) async {
    final session = SessionController(MemorySessionStore());
    await session.restore();
    final router = createAppRouter(
      session: session,
      authRepository: FlowAuthRepository(),
      placementRepository: AuthFlowPlacementRepository(),
      initialLocation: '/register',
    );

    await tester.pumpWidget(LingoRoadApp(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('register_email')),
      'new@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register_password')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Kiểm tra trình độ đầu vào'), findsOneWidget);
    router.dispose();
  });

  testWidgets('chuyển sang Register và validate password', (tester) async {
    final session = SessionController(MemorySessionStore());
    await session.restore();
    final router = createAppRouter(
      session: session,
      authRepository: FlowAuthRepository(),
      placementRepository: AuthFlowPlacementRepository(),
      initialLocation: '/login',
    );

    await tester.pumpWidget(LingoRoadApp(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
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
    router.dispose();
  });
}
