import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:lingoroad_mobile/features/dashboard/domain/dashboard_models.dart';
import 'package:lingoroad_mobile/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:lingoroad_mobile/features/progress/data/progress_repository.dart';
import 'package:lingoroad_mobile/features/progress/domain/progress_models.dart';
import 'package:lingoroad_mobile/features/progress/presentation/progress_view_model.dart';
import 'package:lingoroad_mobile/screens/progress_screen.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../helpers/widget_test_harness.dart';

class _ProgressRepository implements ProgressRepository {
  @override
  Future<List<SkillCatalogItem>> skills() async => const [
    SkillCatalogItem(
      id: 1,
      code: 'grammar',
      name: 'Grammar',
      nameVi: 'Ngữ pháp',
      category: 'grammar',
      parentId: null,
    ),
  ];

  @override
  Future<List<MasteryRow>> mastery() async => const [
    MasteryRow('grammar', .77),
  ];
}

class _DashboardRepository implements DashboardRepository {
  @override
  Future<DashboardData> dashboard() async => const DashboardData(
    name: 'Mai',
    currentCefr: 'A1',
    targetCefr: 'B1',
    dailyGoalMinutes: 30,
    mastery: .77,
    dailyProgress: 1,
    weeklyProgress: .14,
    dueReviews: 0,
    completedLessons: 1,
    xp: 45,
    coins: 3,
    currentStreak: 1,
    longestStreak: 1,
    activeDates: [],
    recentActivity: [],
  );

  @override
  Future<List<QuestData>> quests() async => const [
    QuestData(code: 'daily_lesson', current: 1, target: 1, completed: true),
  ];
}

AppLanguageProvider _language() {
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

void main() {
  testWidgets('Progress hiển thị mastery và gamification từ API thật', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
          ChangeNotifierProvider(
            create: (_) => ProgressViewModel(_ProgressRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => DashboardViewModel(_DashboardRepository()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ProgressScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('77%'), findsWidgets);
    expect(find.text('45 XP'), findsOneWidget);
    expect(find.text('3 xu'), findsOneWidget);
    expect(find.textContaining('chưa có API'), findsNothing);

    await tester.tap(find.text('Thành tích'));
    await tester.pumpAndSettle();

    expect(find.text('Hoàn thành một bài học'), findsOneWidget);
    expect(find.text('1/1'), findsWidgets);
  });

  testWidgets('Progress dùng bề mặt thẻ trắng có viền thay vì mảng màu đặc', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
          ChangeNotifierProvider(
            create: (_) => ProgressViewModel(_ProgressRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => DashboardViewModel(_DashboardRepository()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ProgressScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final key in const [
      Key('progress_cefr_hero'),
      Key('progress_xp_stat'),
      Key('progress_streak_stat'),
    ]) {
      final decoration = tester.widget<Container>(find.byKey(key)).decoration!
          as BoxDecoration;
      expect(decoration.color, AppTheme.light.colorScheme.surface);
      expect(decoration.border, isA<Border>());
    }
  });
}
