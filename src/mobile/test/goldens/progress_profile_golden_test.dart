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
import 'package:lingoroad_mobile/screens/notification_settings_screen.dart';
import 'package:lingoroad_mobile/screens/profile_screen.dart';
import 'package:lingoroad_mobile/screens/progress_screen.dart';
import 'package:lingoroad_mobile/screens/streak_details_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/widget_test_harness.dart';

/// Baselines are deliberately produced and compared only by the pinned Linux
/// Flutter runtime. This file still exercises deterministic repositories on
/// every host through the responsive tests below.
final _canCompareGolden = Platform.isLinux;

enum _TaskThreeSurface {
  progress,
  progressSkills,
  progressAchievements,
  profile,
  settings,
  streak,
}

extension on _TaskThreeSurface {
  String get goldenName => switch (this) {
    _TaskThreeSurface.progress => 'progress_overview',
    _TaskThreeSurface.progressSkills => 'progress_skills',
    _TaskThreeSurface.progressAchievements => 'progress_achievements',
    _TaskThreeSurface.profile => 'profile_loaded',
    _TaskThreeSurface.settings => 'settings_loaded',
    _TaskThreeSurface.streak => 'streak_loaded',
  };
}

class _GoldenAuthRepository implements AuthRepository {
  @override
  Future<UserProfile> getProfile() async => const UserProfile(
    id: 'golden-task-three',
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
    profileSetupCompleted: true,
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

class _GoldenProgressRepository implements ProgressRepository {
  @override
  Future<List<SkillCatalogItem>> skills() async => const [
    SkillCatalogItem(
      id: 1,
      code: 'vocabulary.animals',
      name: 'Animals',
      nameVi: 'Động vật',
      category: 'vocabulary',
      parentId: null,
    ),
    SkillCatalogItem(
      id: 2,
      code: 'grammar.present',
      name: 'Present simple',
      nameVi: 'Thì hiện tại',
      category: 'grammar',
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
  ];

  @override
  Future<List<MasteryRow>> mastery() async => const [
    MasteryRow('vocabulary.animals', .92),
    MasteryRow('grammar.present', .68),
    MasteryRow('listening.basic', .52),
  ];
}

class _GoldenDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardData> dashboard() async => DashboardData(
    name: 'Linh Mai',
    currentCefr: 'B1',
    targetCefr: 'B2',
    dailyGoalMinutes: 30,
    mastery: .75,
    dailyProgress: .5,
    weeklyProgress: .4,
    dueReviews: 3,
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
    QuestData(code: 'daily_review', current: 3, target: 5, completed: false),
  ];
}

AppLanguageProvider _language() {
  Map<String, dynamic> load(String path) =>
      json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return AppLanguageProvider.test(
    translations: {
      AppLanguage.vi: load('assets/translations/vi.json'),
      AppLanguage.en: load('assets/translations/en.json'),
    },
    currentLanguage: AppLanguage.vi,
  );
}

Widget _surface(_TaskThreeSurface surface) {
  final auth = _GoldenAuthRepository();
  final dashboard = _GoldenDashboardRepository();
  final language = _language();
  final content = switch (surface) {
    _TaskThreeSurface.progress ||
    _TaskThreeSurface.progressSkills ||
    _TaskThreeSurface.progressAchievements => const Scaffold(
      body: ProgressScreen(),
    ),
    _TaskThreeSurface.profile => const Scaffold(body: ProfileScreen()),
    _TaskThreeSurface.settings => const NotificationSettingsScreen(),
    _TaskThreeSurface.streak => const StreakDetailsScreen(),
  };
  return MultiProvider(
    providers: [
      Provider<AuthRepository>.value(value: auth),
      ChangeNotifierProvider(
        create: (_) => ProgressViewModel(_GoldenProgressRepository()),
      ),
      ChangeNotifierProvider(create: (_) => DashboardViewModel(dashboard)),
      ChangeNotifierProvider<SessionController>.value(
        value: SessionController(
          MemorySessionStore('golden-access', 'refresh'),
        ),
      ),
      ChangeNotifierProvider<AppLanguageProvider>.value(value: language),
      ChangeNotifierProvider(
        create: (_) => AppThemeProvider(initialMode: ThemeMode.light),
      ),
    ],
    child: content,
  );
}

Future<void> _prepareSurface(
  WidgetTester tester,
  _TaskThreeSurface surface,
) async {
  switch (surface) {
    case _TaskThreeSurface.progressSkills:
      await tester.tap(find.text('Kỹ năng'));
      await tester.pumpAndSettle();
    case _TaskThreeSurface.progressAchievements:
      await tester.tap(find.text('Thành tích'));
      await tester.pumpAndSettle();
    default:
      break;
  }
}

void _expectLearnerTargetsAtLeast48(WidgetTester tester) {
  final controls = find.byWidgetPredicate(
    (widget) =>
        widget is IconButton ||
        widget is FilledButton ||
        widget is OutlinedButton ||
        widget is TextButton ||
        widget is ListTile,
  );
  for (var index = 0; index < controls.evaluate().length; index++) {
    final finder = controls.at(index);
    final size = tester.getSize(finder);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  }
}

void main() {
  setUpAll(loadLingoRoadGoldenFonts);

  for (final surface in _TaskThreeSurface.values) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final brightness = mode == ThemeMode.light ? 'light' : 'dark';
      testWidgets('${surface.goldenName} $brightness golden', (tester) async {
        await pumpLingoRoadGoldenSurface(
          tester,
          child: _surface(surface),
          themeMode: mode,
        );
        await _prepareSurface(tester, surface);
        await expectLater(
          find.byKey(lingoRoadGoldenRootKey),
          matchesGoldenFile(
            'progress-profile/${surface.goldenName}_$brightness.png',
          ),
        );
      }, skip: !_canCompareGolden);
    }
  }

  const profiles = [
    (name: 'compact-320', size: Size(320, 844), textScale: 1.0),
    (name: 'standard-390', size: Size(390, 844), textScale: 1.0),
    (name: 'wide-600', size: Size(600, 844), textScale: 1.0),
    (name: 'text-scale-1.3', size: Size(390, 844), textScale: 1.3),
  ];
  for (final profile in profiles) {
    testWidgets('task 3 surfaces render without overflow at ${profile.name}', (
      tester,
    ) async {
      for (final surface in _TaskThreeSurface.values) {
        await pumpLingoRoadGoldenSurface(
          tester,
          child: _surface(surface),
          themeMode: ThemeMode.light,
          size: profile.size,
          textScaleFactor: profile.textScale,
        );
        await _prepareSurface(tester, surface);
        expect(tester.takeException(), isNull, reason: surface.goldenName);
      }
    });
  }

  testWidgets('task 3 learner controls meet the 48px touch target', (
    tester,
  ) async {
    for (final surface in _TaskThreeSurface.values) {
      await pumpLingoRoadGoldenSurface(
        tester,
        child: _surface(surface),
        themeMode: ThemeMode.light,
      );
      await _prepareSurface(tester, surface);
      _expectLearnerTargetsAtLeast48(tester);
    }
  });
}
