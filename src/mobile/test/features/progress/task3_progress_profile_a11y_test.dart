import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/core/theme/app_theme_provider.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/domain/user_profile.dart';
import 'package:lingoroad_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:lingoroad_mobile/features/dashboard/domain/dashboard_models.dart';
import 'package:lingoroad_mobile/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:lingoroad_mobile/features/progress/data/progress_repository.dart';
import 'package:lingoroad_mobile/features/progress/domain/progress_models.dart';
import 'package:lingoroad_mobile/features/progress/presentation/progress_view_model.dart';
import 'package:lingoroad_mobile/screens/profile_screen.dart';
import 'package:lingoroad_mobile/screens/progress_screen.dart';
import 'package:lingoroad_mobile/screens/notification_settings_screen.dart';
import 'package:lingoroad_mobile/screens/streak_details_screen.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../helpers/widget_test_harness.dart';

class _UnpracticedProgressRepository implements ProgressRepository {
  @override
  Future<List<SkillCatalogItem>> skills() async => const [
    SkillCatalogItem(
      id: 1,
      code: 'grammar.present',
      name: 'Present tense',
      nameVi: 'Thì hiện tại',
      category: 'grammar',
      parentId: null,
    ),
  ];

  @override
  Future<List<MasteryRow>> mastery() async => const [];
}

class _TaskDashboardRepository implements DashboardRepository {
  const _TaskDashboardRepository();

  @override
  Future<DashboardData> dashboard() async => DashboardData(
    name: 'Linh Mai',
    currentCefr: 'B1',
    targetCefr: 'B2',
    dailyGoalMinutes: 30,
    mastery: .62,
    dailyProgress: .5,
    weeklyProgress: .4,
    dueReviews: 2,
    completedLessons: 2,
    xp: 1240,
    coins: 12,
    currentStreak: 12,
    longestStreak: 18,
    activeDates: [DateTime.now()],
    recentActivity: const [],
  );

  @override
  Future<List<QuestData>> quests() async => const [
    QuestData(code: 'daily_lesson', current: 1, target: 1, completed: true),
  ];
}

class _TaskProfileRepository implements AuthRepository {
  const _TaskProfileRepository();

  @override
  Future<UserProfile> getProfile() async => const UserProfile(
    id: 'task-3-user',
    email: 'linh.mai@example.com',
    name: 'Linh Mai',
    targetCefr: 'B2',
    cefrLevel: 'B1',
    level: 12,
    badgesCount: 6,
    dailyGoalMinutes: 30,
    learningPurpose: 'Work',
    focusSkillIds: [1],
    studyReminderEnabled: true,
    reminderTime: '19:30',
    emailNotifications: false,
    appUpdates: true,
  );

  @override
  Future<UserProfile> completeProfileSetup({
    required String name,
    required String targetCefr,
    required int dailyGoalMinutes,
  }) => getProfile();

  @override
  Future<UserProfile> updateProfile(Map<String, Object?> values) =>
      getProfile();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> logout(String? refreshToken) async {}

  @override
  Future<AuthTokens> login({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<AuthTokens> register({
    required String email,
    required String password,
    String? name,
  }) => throw UnimplementedError();
}

AppLanguageProvider _language() {
  Map<String, dynamic> load(String path) =>
      json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return AppLanguageProvider.test(
    translations: {
      AppLanguage.vi: load('assets/translations/vi.json'),
      AppLanguage.en: load('assets/translations/en.json'),
    },
  );
}

Widget _progress() => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
    ChangeNotifierProvider(
      create: (_) => ProgressViewModel(_UnpracticedProgressRepository()),
    ),
    ChangeNotifierProvider(
      create: (_) => DashboardViewModel(const _TaskDashboardRepository()),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: ProgressScreen()),
  ),
);

Widget _profile() {
  final session = SessionController(MemorySessionStore('access', 'refresh'));
  return MultiProvider(
    providers: [
      Provider<AuthRepository>.value(value: const _TaskProfileRepository()),
      ChangeNotifierProvider<SessionController>.value(value: session),
      ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: ProfileScreen()),
    ),
  );
}

Widget _streak() => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
    ChangeNotifierProvider(
      create: (_) => DashboardViewModel(const _TaskDashboardRepository()),
    ),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const StreakDetailsScreen()),
);

Widget _notificationSettings() => MultiProvider(
  providers: [
    Provider<AuthRepository>.value(value: const _TaskProfileRepository()),
    ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
    ChangeNotifierProvider(
      create: (_) => AppThemeProvider(initialMode: ThemeMode.light),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const NotificationSettingsScreen(),
  ),
);

void main() {
  testWidgets('progress explains empty strengths and improvements separately', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(tester, _progress());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('progress_strengths_empty')), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('progress_improvements_empty')),
      findsOneWidget,
    );
  });

  testWidgets(
    'profile renders deterministic initials instead of a remote avatar',
    (tester) async {
      await pumpWidgetWithLingoRoadScreenUtil(tester, _profile());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_initials')), findsOneWidget);
      expect(find.text('LM'), findsOneWidget);
    },
  );

  testWidgets('streak month controls expose accessible navigation labels', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(tester, _streak());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('streak_previous_month')), findsOneWidget);
    expect(find.byKey(const Key('streak_next_month')), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('streak_previous_month'))),
      matchesSemantics(
        label: 'Tháng trước',
        isButton: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets(
    'settings groups expose their visible heading to assistive tech',
    (tester) async {
      await pumpWidgetWithLingoRoadScreenUtil(tester, _notificationSettings());
      await tester.pumpAndSettle();

      final heading = find.byKey(const Key('settings_notifications_heading'));
      expect(heading, findsOneWidget);
      expect(
        tester.getSemantics(heading),
        matchesSemantics(label: 'Thông báo', isHeader: true),
      );
    },
  );
}
