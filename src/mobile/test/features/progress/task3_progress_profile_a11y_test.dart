import 'dart:async';
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

class _ProgressDataRepository implements ProgressRepository {
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
    SkillCatalogItem(
      id: 2,
      code: 'vocabulary.travel',
      name: 'Travel vocabulary',
      nameVi: 'Từ vựng du lịch',
      category: 'vocabulary',
      parentId: null,
    ),
    SkillCatalogItem(
      id: 3,
      code: 'listening.basic',
      name: 'Basic listening',
      nameVi: 'Nghe cơ bản',
      category: 'listening',
      parentId: null,
    ),
    SkillCatalogItem(
      id: 4,
      code: 'reading.basic',
      name: 'Basic reading',
      nameVi: 'Đọc cơ bản',
      category: 'reading',
      parentId: null,
    ),
  ];

  @override
  Future<List<MasteryRow>> mastery() async => const [
    MasteryRow('grammar.present', .68),
    MasteryRow('vocabulary.travel', .92),
    MasteryRow('listening.basic', .52),
    MasteryRow('reading.basic', .55),
  ];
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
    activeDates: [DateTime.utc(2025, 10, 12)],
    recentActivity: const [],
  );

  @override
  Future<List<QuestData>> quests() async => const [
    QuestData(code: 'daily_lesson', current: 1, target: 1, completed: true),
  ];
}

class _PendingProgressRepository implements ProgressRepository {
  final skillsCompleter = Completer<List<SkillCatalogItem>>();
  final masteryCompleter = Completer<List<MasteryRow>>();

  @override
  Future<List<SkillCatalogItem>> skills() => skillsCompleter.future;

  @override
  Future<List<MasteryRow>> mastery() => masteryCompleter.future;
}

class _RetryProgressRepository implements ProgressRepository {
  bool shouldFail = true;

  @override
  Future<List<SkillCatalogItem>> skills() async {
    if (shouldFail) throw StateError('offline');
    return _UnpracticedProgressRepository().skills();
  }

  @override
  Future<List<MasteryRow>> mastery() async {
    if (shouldFail) throw StateError('offline');
    return _UnpracticedProgressRepository().mastery();
  }
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

class _RetryProfileRepository extends _TaskProfileRepository {
  bool shouldFail = true;

  @override
  Future<UserProfile> getProfile() async {
    if (shouldFail) throw StateError('offline');
    return super.getProfile();
  }
}

class _PendingProfileRepository extends _TaskProfileRepository {
  final completer = Completer<UserProfile>();

  @override
  Future<UserProfile> getProfile() => completer.future;
}

class _RetryDashboardRepository extends _TaskDashboardRepository {
  bool shouldFail = true;

  @override
  Future<DashboardData> dashboard() async {
    if (shouldFail) throw StateError('offline');
    return super.dashboard();
  }

  @override
  Future<List<QuestData>> quests() async {
    if (shouldFail) throw StateError('offline');
    return super.quests();
  }
}

class _PendingDashboardRepository extends _TaskDashboardRepository {
  final dashboardCompleter = Completer<DashboardData>();
  final questsCompleter = Completer<List<QuestData>>();

  @override
  Future<DashboardData> dashboard() => dashboardCompleter.future;

  @override
  Future<List<QuestData>> quests() => questsCompleter.future;
}

class _MaintenanceDashboardRepository extends _TaskDashboardRepository {
  const _MaintenanceDashboardRepository();

  @override
  Future<DashboardData> dashboard() async => DashboardData(
    name: 'Linh Mai',
    currentCefr: 'B1',
    targetCefr: 'B1',
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
    activeDates: const [],
    recentActivity: const [],
  );
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

Widget _progress({
  ProgressRepository? repository,
  DashboardRepository? dashboardRepository,
  int initialTab = 0,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
    ChangeNotifierProvider(
      create: (_) =>
          ProgressViewModel(repository ?? _UnpracticedProgressRepository()),
    ),
    ChangeNotifierProvider(
      create: (_) => DashboardViewModel(
        dashboardRepository ?? const _TaskDashboardRepository(),
      ),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: ProgressScreen(initialTab: initialTab)),
  ),
);

Widget _profile({AuthRepository? repository}) {
  final session = SessionController(MemorySessionStore('access', 'refresh'));
  return MultiProvider(
    providers: [
      Provider<AuthRepository>.value(
        value: repository ?? const _TaskProfileRepository(),
      ),
      ChangeNotifierProvider<SessionController>.value(value: session),
      ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: ProfileScreen()),
    ),
  );
}

Widget _streak({DateTime? initialMonth, DashboardRepository? repository}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
        ChangeNotifierProvider(
          create: (_) => DashboardViewModel(
            repository ?? const _TaskDashboardRepository(),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: StreakDetailsScreen(initialMonth: initialMonth),
      ),
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
  testWidgets('progress overview groups CEFR, insight and compact stats', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      _progress(repository: _ProgressDataRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('progress_cefr_hero')), findsOneWidget);
    expect(find.byKey(const Key('progress_compact_stats')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('progress_focus_insight')),
      300,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey('progress-overview')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byKey(const Key('progress_focus_insight')), findsOneWidget);
  });

  testWidgets(
    'progress labels a reached CEFR target without a redundant arrow',
    (tester) async {
      await pumpWidgetWithLingoRoadScreenUtil(
        tester,
        _progress(dashboardRepository: const _MaintenanceDashboardRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('B1 · Đang củng cố'), findsOneWidget);
      expect(find.text('B1 → B1'), findsNothing);
    },
  );

  testWidgets('progress skills uses one scannable group and a daily focus', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      _progress(repository: _ProgressDataRepository(), initialTab: 1),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('progress_skills_group')), findsOneWidget);
    expect(find.byKey(const Key('progress_skill_listening')), findsOneWidget);
    expect(find.byKey(const Key('progress_skills_focus')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('progress_skills_group')),
        matching: find.byType(Divider),
      ),
      findsNothing,
    );
    expect(find.text('Đọc'), findsOneWidget);
  });

  testWidgets(
    'progress achievements joins motivation stats and quest progress',
    (tester) async {
      await pumpWidgetWithLingoRoadScreenUtil(tester, _progress(initialTab: 2));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('progress_achievement_stats')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('progress_quests_group')), findsOneWidget);
    },
  );

  testWidgets('progress explains empty strengths and improvements separately', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(tester, _progress());
    await tester.pumpAndSettle();

    final strengths = find.byKey(const Key('progress_strengths_empty'));
    expect(strengths, findsOneWidget);
    expect(
      tester.getSemantics(strengths),
      matchesSemantics(
        label:
            'Chưa đủ dữ liệu để xác định điểm mạnh. Hãy hoàn thành thêm bài học.',
        isLiveRegion: true,
      ),
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    final improvements = find.byKey(const Key('progress_improvements_empty'));
    expect(improvements, findsOneWidget);
    expect(
      tester.getSemantics(improvements),
      matchesSemantics(
        label:
            'Chưa có kỹ năng nào cần cải thiện. Hãy học thêm để nhận phân tích cá nhân hóa.',
        isLiveRegion: true,
      ),
    );
  });

  testWidgets('progress announces loading and labels separate empty states', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      _progress(repository: _PendingProgressRepository()),
    );
    await tester.pump();

    final loading = find.byKey(const Key('progress_loading'));
    expect(loading, findsOneWidget);
    expect(
      tester.getSemantics(loading),
      matchesSemantics(label: 'Đang tải tiến độ học tập', isLiveRegion: true),
    );
  });

  testWidgets('progress announces an error and retries without losing state', (
    tester,
  ) async {
    final repository = _RetryProgressRepository();
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      _progress(repository: repository),
    );
    await tester.pumpAndSettle();

    final error = find.byKey(const Key('progress_error'));
    expect(error, findsOneWidget);
    expect(
      tester.getSemantics(error),
      matchesSemantics(
        label: 'Không thể tải tiến độ học tập. Vui lòng thử lại.',
        isLiveRegion: true,
      ),
    );
    expect(find.byKey(const Key('progress_retry')), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('progress_retry'))),
      matchesSemantics(
        label: 'Thử tải lại tiến độ học tập',
        isButton: true,
        hasTapAction: true,
      ),
    );

    repository.shouldFail = false;
    await tester.tap(find.byKey(const Key('progress_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('progress_strengths_empty')), findsOneWidget);
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

  testWidgets('profile announces its loading status', (tester) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      _profile(repository: _PendingProfileRepository()),
    );
    await tester.pump();

    final loading = find.byKey(const Key('profile_loading'));
    expect(loading, findsOneWidget);
    expect(
      tester.getSemantics(loading),
      matchesSemantics(label: 'Đang tải thông tin cá nhân', isLiveRegion: true),
    );
  });

  testWidgets('profile announces a failure and its retry restores content', (
    tester,
  ) async {
    final repository = _RetryProfileRepository();
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      _profile(repository: repository),
    );
    await tester.pumpAndSettle();

    final error = find.byKey(const Key('profile_load_error'));
    expect(error, findsOneWidget);
    expect(
      tester.getSemantics(error),
      matchesSemantics(
        label: 'Không thể tải thông tin cá nhân',
        isLiveRegion: true,
      ),
    );
    repository.shouldFail = false;
    expect(
      tester.getSemantics(find.byKey(const Key('profile_retry'))),
      matchesSemantics(
        label: 'Thử tải lại thông tin cá nhân',
        isButton: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.byKey(const Key('profile_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_initials')), findsOneWidget);
  });

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
    'streak accepts a fixed calendar month for deterministic output',
    (tester) async {
      await pumpWidgetWithLingoRoadScreenUtil(
        tester,
        _streak(initialMonth: DateTime.utc(2025, 10, 1)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tháng 10 2025'), findsOneWidget);
    },
  );

  testWidgets('streak announces its loading status', (tester) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      _streak(repository: _PendingDashboardRepository()),
    );
    await tester.pump();

    final loading = find.byKey(const Key('streak_loading'));
    expect(loading, findsOneWidget);
    expect(
      tester.getSemantics(loading),
      matchesSemantics(label: 'Đang tải chuỗi học tập', isLiveRegion: true),
    );
  });

  testWidgets('streak announces an error and retries to its calendar', (
    tester,
  ) async {
    final repository = _RetryDashboardRepository();
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      _streak(repository: repository),
    );
    await tester.pumpAndSettle();

    final error = find.byKey(const Key('streak_error'));
    expect(error, findsOneWidget);
    expect(
      tester.getSemantics(error),
      matchesSemantics(
        label: 'Không thể tải chuỗi học tập. Vui lòng thử lại.',
        isLiveRegion: true,
      ),
    );
    repository.shouldFail = false;
    expect(
      tester.getSemantics(find.byKey(const Key('streak_retry'))),
      matchesSemantics(
        label: 'Thử tải lại chuỗi học tập',
        isButton: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.byKey(const Key('streak_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('streak_current')), findsOneWidget);
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
