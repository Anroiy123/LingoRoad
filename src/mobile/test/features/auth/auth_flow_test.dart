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
