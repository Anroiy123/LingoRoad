import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/domain/user_profile.dart';
import 'package:lingoroad_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:lingoroad_mobile/features/dashboard/domain/dashboard_models.dart';
import 'package:lingoroad_mobile/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:lingoroad_mobile/features/lesson/domain/lesson_models.dart';
import 'package:lingoroad_mobile/screens/home_screen.dart';
import 'package:lingoroad_mobile/screens/streak_details_screen.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../helpers/widget_test_harness.dart';

const dashboardData = DashboardData(
  name: 'Mai',
  currentCefr: 'A2',
  targetCefr: 'B1',
  dailyGoalMinutes: 30,
  mastery: .42,
  dailyProgress: .5,
  weeklyProgress: .25,
  dueReviews: 3,
  completedLessons: 2,
  xp: 125,
  coins: 7,
  currentStreak: 4,
  longestStreak: 6,
  activeDates: [],
  todayLesson: TodayLesson(
    id: 'lesson-1',
    slug: 'present-simple',
    title: 'Present Simple',
    titleVi: 'Hiện tại đơn',
    skillCode: 'grammar.tenses.present_simple',
    cefr: 'A1',
    itemCount: 5,
  ),
  recentActivity: [],
);

class FakeDashboardRepository implements DashboardRepository {
  DashboardData data = dashboardData;
  Object? error;
  int calls = 0;
  Completer<DashboardData>? completer;

  @override
  Future<DashboardData> dashboard() async {
    calls++;
    if (error != null) throw error!;
    return completer?.future ?? data;
  }

  @override
  Future<List<QuestData>> quests() async {
    if (error != null) throw error!;
    return const [
      QuestData(code: 'daily_lesson', current: 0, target: 1, completed: false),
      QuestData(code: 'daily_xp', current: 20, target: 50, completed: false),
    ];
  }
}

class FakeHomeAuthRepository implements AuthRepository {
  FakeHomeAuthRepository(this.profile);

  final UserProfile profile;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<UserProfile> completeProfileSetup({
    required String name,
    required String targetCefr,
    required int dailyGoalMinutes,
  }) async => profile;

  @override
  Future<UserProfile> getProfile() async => profile;

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async => const AuthTokens(accessToken: 'token', refreshToken: 'refresh');

  @override
  Future<void> logout(String? refreshToken) async {}

  @override
  Future<AuthTokens> register({
    required String email,
    required String password,
    String? name,
  }) async => const AuthTokens(accessToken: 'token', refreshToken: 'refresh');

  @override
  Future<UserProfile> updateProfile(Map<String, Object?> values) async =>
      profile;
}

AppLanguageProvider languageProvider() {
  final vi =
      json.decode(File('assets/translations/vi.json').readAsStringSync())
          as Map<String, dynamic>;
  final en =
      json.decode(File('assets/translations/en.json').readAsStringSync())
          as Map<String, dynamic>;
  return AppLanguageProvider.test(
    translations: {AppLanguage.vi: vi, AppLanguage.en: en},
  );
}

Widget homeApp(
  FakeDashboardRepository repository, {
  AuthRepository? authRepository,
}) => MultiProvider(
  providers: [
    Provider<AuthRepository?>.value(value: authRepository),
    ChangeNotifierProvider<AppLanguageProvider>.value(
      value: languageProvider(),
    ),
    ChangeNotifierProvider<DashboardViewModel>(
      create: (_) => DashboardViewModel(repository),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: HomeScreen()),
  ),
);

Widget streakApp(FakeDashboardRepository repository) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppLanguageProvider>.value(
      value: languageProvider(),
    ),
    ChangeNotifierProvider<DashboardViewModel>(
      create: (_) => DashboardViewModel(repository),
    ),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const StreakDetailsScreen()),
);

void main() {
  testWidgets('Home hiển thị dashboard API, không còn tên và lesson hardcode', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chào Mai!'), findsOneWidget);
    expect(find.text('Hiện tại đơn'), findsOneWidget);
    expect(find.text('A2 → B1 · Thành thạo 42%'), findsOneWidget);
    expect(find.text('125'), findsOneWidget);
    expect(find.text('Hùng'), findsNothing);
    expect(find.text('Giao tiếp tại sân bay'), findsNothing);
  });

  testWidgets('Home có loading và error/retry', (tester) async {
    final repository = FakeDashboardRepository()
      ..completer = Completer<DashboardData>();
    await pumpWidgetWithLingoRoadScreenUtil(tester, homeApp(repository));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.completer!.completeError(
      const ApiException(code: 'network_unavailable', message: 'offline'),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_error')), findsOneWidget);

    repository.completer = null;
    await tester.tap(find.byKey(const Key('home_retry')));
    await tester.pumpAndSettle();
    expect(find.text('Chào Mai!'), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('Chi tiết streak dùng số liệu API thay vì mock', (tester) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      streakApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('streak_current')), findsOneWidget);
    expect(find.text('4 Ngày'), findsOneWidget);
    expect(find.text('6 ngày'), findsOneWidget);
    expect(find.text('12 ngày'), findsNothing);
    expect(find.text('18 ngày'), findsNothing);
  });

  testWidgets(
    'Home dùng thương hiệu chuẩn, avatar initials có semantics và màu ổn định',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = FakeDashboardRepository();
      await pumpWidgetWithLingoRoadScreenUtil(tester, homeApp(repository));
      await tester.pumpAndSettle();

      expect(find.text('LingoRoad'), findsOneWidget);
      expect(find.text('lingRoad'), findsNothing);
      expect(find.text('lingoRoad'), findsNothing);
      expect(find.text('M'), findsOneWidget);
      expect(find.bySemanticsLabel('Ảnh đại diện của Mai'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      final firstAvatar = tester.widget<CircleAvatar>(
        find.byKey(const Key('home_avatar')),
      );
      final firstColor = firstAvatar.backgroundColor;
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpWidgetWithLingoRoadScreenUtil(tester, homeApp(repository));
      await tester.pumpAndSettle();
      final secondAvatar = tester.widget<CircleAvatar>(
        find.byKey(const Key('home_avatar')),
      );
      expect(secondAvatar.backgroundColor, firstColor);
      semantics.dispose();
    },
  );

  testWidgets('Home fallback initials sang email profile khi tên trống', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = FakeDashboardRepository()
      ..data = const DashboardData(
        name: '',
        currentCefr: 'A2',
        targetCefr: 'B1',
        dailyGoalMinutes: 30,
        mastery: .42,
        dailyProgress: .5,
        weeklyProgress: .25,
        dueReviews: 3,
        completedLessons: 2,
        xp: 125,
        coins: 7,
        currentStreak: 4,
        longestStreak: 6,
        activeDates: [],
        recentActivity: [],
      );

    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(
        repository,
        authRepository: FakeHomeAuthRepository(
          const UserProfile(
            id: 'learner-1',
            email: 'fallback.mai@example.com',
            name: '',
            targetCefr: 'B1',
            cefrLevel: 'A2',
            level: 2,
            badgesCount: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('F'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Ảnh đại diện của fallback.mai@example.com'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('thẻ bài học hôm nay dùng màu semantic phẳng, không gradient', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    final card = tester.widget<Container>(
      find.byKey(const Key('home_today_lesson')),
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.gradient, isNull);
    expect(decoration.color, AppColors.primary);
  });
}
