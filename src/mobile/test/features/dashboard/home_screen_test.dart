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
import 'package:lingoroad_mobile/widgets/common.dart';
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
  List<QuestData> questData = const [
    QuestData(code: 'daily_lesson', current: 0, target: 1, completed: false),
    QuestData(code: 'daily_xp', current: 20, target: 50, completed: false),
  ];
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
    return questData;
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
  ThemeData? theme,
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
    theme: theme ?? AppTheme.light,
    home: const Scaffold(body: HomeScreen()),
  ),
);

Widget streakApp(FakeDashboardRepository repository, {ThemeData? theme}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppLanguageProvider>.value(
          value: languageProvider(),
        ),
        ChangeNotifierProvider<DashboardViewModel>(
          create: (_) => DashboardViewModel(repository),
        ),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        home: const StreakDetailsScreen(),
      ),
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
    expect(find.text('A2 → B1 · 42% thành thạo'), findsOneWidget);
    expect(find.text('Hùng'), findsNothing);
    expect(find.text('Giao tiếp tại sân bay'), findsNothing);
  });

  testWidgets(
    'Home header removes duplicate stats and uses one clear hierarchy',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWidgetWithLingoRoadScreenUtil(
        tester,
        homeApp(FakeDashboardRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('LingoRoad'), findsOneWidget);
      expect(find.text('4 ngày'), findsOneWidget);
      expect(find.text('A2 → B1 · 42% thành thạo'), findsOneWidget);
      expect(find.text('A2 → B1'), findsNothing);
      expect(find.text('42% thành thạo'), findsNothing);
      expect(find.byKey(const Key('header_xp')), findsOneWidget);
      expect(find.byKey(const Key('header_coins')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('header_coins')),
          matching: find.byIcon(Icons.toll_rounded),
        ),
        findsOneWidget,
      );
      expect(find.text('125'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.byKey(const Key('home_header_divider')), findsNothing);
      expect(find.byType(Badge), findsNothing);
      expect(find.text('A2 → B1 · Thành thạo 42%'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('home_summary_hero')),
          matching: find.text('125 XP'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('home_summary_hero')),
          matching: find.text('7 Xu'),
        ),
        findsNothing,
      );
      expect(find.bySemanticsLabel('Chuỗi học tập 4 ngày'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('hero chào mừng nằm trực tiếp trên canvas, không phải thẻ', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_summary_hero')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('home_summary_hero')),
        matching: find.byType(AppCard),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('home_summary_hero')),
        matching: find.byType(Divider),
      ),
      findsNothing,
    );
  });

  testWidgets('XP và Xu được đặt ở header, thay cho pill trình độ', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    final xpPosition = tester.getTopLeft(find.byKey(const Key('header_xp')));
    final heroPosition = tester.getTopLeft(
      find.byKey(const Key('home_summary_hero')),
    );

    expect(xpPosition.dy, lessThan(heroPosition.dy));
    expect(find.bySemanticsLabel('Trình độ A2'), findsNothing);
  });

  testWidgets('Header Home ghim ở đầu khi cuộn nội dung', (tester) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    final header = find.byKey(const Key('home_sticky_header'));
    final content = find.byKey(const Key('home_content_scroll'));
    expect(header, findsOneWidget);
    expect(content, findsOneWidget);
    expect(find.descendant(of: content, matching: header), findsNothing);
    expect(
      tester.widget<ListView>(content).physics,
      isA<AlwaysScrollableScrollPhysics>(),
    );
  });

  testWidgets('Kế hoạch hôm nay nằm trong một thẻ viền chung', (tester) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppCard && widget.key == const Key('home_daily_plan'),
      ),
      findsOneWidget,
    );
    final dailyPlan = find.byKey(const Key('home_daily_plan'));
    expect(
      find.descendant(
        of: dailyPlan,
        matching: find.byKey(const Key('home_daily_review_card')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dailyPlan,
        matching: find.byKey(const Key('home_daily_xp_card')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Kế hoạch hôm nay đứng trước bài học hôm nay', (tester) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    final dailyPlanPosition = tester.getTopLeft(
      find.byKey(const Key('home_daily_plan')),
    );
    final todayLessonPosition = tester.getTopLeft(
      find.byKey(const Key('home_today_lesson')),
    );

    expect(dailyPlanPosition.dy, lessThan(todayLessonPosition.dy));
  });

  testWidgets('Bài học hôm nay giữ CTA nhưng dùng card gọn', (tester) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_start_lesson')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('home_today_lesson'))).height,
      132,
    );
    expect(
      tester.getSize(find.byKey(const Key('home_start_lesson'))).width,
      48,
    );
  });

  testWidgets('Bài học hôm nay và luyện phát âm cùng một carousel ngang', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    final carousel = find.byKey(const Key('home_learning_carousel'));
    expect(carousel, findsOneWidget);
    expect(
      tester.widget<SingleChildScrollView>(carousel).scrollDirection,
      Axis.horizontal,
    );

    final lessonSize = tester.getSize(
      find.byKey(const Key('home_today_lesson')),
    );
    final practiceSize = tester.getSize(
      find.descendant(
        of: find.byKey(const Key('home_ai_practice')),
        matching: find.byType(AppCard),
      ),
    );
    expect(lessonSize.width, greaterThan(practiceSize.width));
    expect(lessonSize.height, practiceSize.height);

    final practiceInitialLeft = tester
        .getTopLeft(find.byKey(const Key('home_ai_practice')))
        .dx;
    await tester.drag(carousel, const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('home_ai_practice'))).dx,
      lessThan(practiceInitialLeft),
    );
  });

  testWidgets('Kế hoạch hôm nay dùng tiêu đề lớn hơn', (tester) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    final heading = tester.widget<Text>(find.text('Kế hoạch hôm nay'));
    expect(heading.style?.fontSize, 20);
  });

  testWidgets('Mục tiêu phút học dùng cùng hàng nhiệm vụ với ôn tập', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    final greeting = find.byKey(const Key('home_summary_hero'));
    final dailyPlan = find.byKey(const Key('home_daily_plan'));
    final levelSummary = find.byKey(const Key('home_level_summary'));
    final masteryProgress = find.byKey(const Key('home_mastery_progress'));
    final dailyGoal = find.byKey(const Key('home_daily_goal_row'));
    final dailyProgress = find.byKey(const Key('home_daily_progress'));
    final reviewRow = find.byKey(const Key('home_daily_review_card'));

    expect(
      find.descendant(of: greeting, matching: masteryProgress),
      findsNothing,
    );
    expect(
      tester.getTopLeft(levelSummary).dy,
      greaterThan(tester.getTopLeft(dailyPlan).dy),
    );
    expect(
      tester.getTopLeft(masteryProgress).dy,
      greaterThan(tester.getTopLeft(levelSummary).dy),
    );
    expect(
      tester.getBottomRight(masteryProgress).dy,
      lessThan(tester.getTopLeft(dailyGoal).dy),
    );
    expect(tester.getSize(dailyGoal).height, greaterThanOrEqualTo(56));
    expect(
      tester.getSize(dailyGoal).height,
      greaterThanOrEqualTo(tester.getSize(reviewRow).height),
    );
    expect(
      tester.getTopLeft(dailyProgress).dx,
      greaterThan(tester.getTopLeft(reviewRow).dx),
    );
  });

  testWidgets(
    'Kế hoạch gộp trình độ với mức thành thạo mà không lặp pill thời lượng',
    (tester) async {
      await pumpWidgetWithLingoRoadScreenUtil(
        tester,
        homeApp(FakeDashboardRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('15 / 30 phút'), findsNothing);
      expect(find.text('50%'), findsNothing);
      expect(find.text('A2 → B1 · 42% thành thạo'), findsOneWidget);
    },
  );

  testWidgets('Nhiệm vụ gần xong báo số XP còn thiếu', (tester) async {
    final repository = FakeDashboardRepository()
      ..questData = const [
        QuestData(
          code: 'daily_review',
          current: 2,
          target: 5,
          completed: false,
        ),
        QuestData(code: 'daily_xp', current: 45, target: 50, completed: false),
      ];
    await pumpWidgetWithLingoRoadScreenUtil(tester, homeApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Còn 5 XP'), findsOneWidget);
  });

  testWidgets('Kế hoạch hoàn thành dùng trạng thái xanh rõ ràng', (
    tester,
  ) async {
    final repository = FakeDashboardRepository()
      ..data = const DashboardData(
        name: 'Mai',
        currentCefr: 'A2',
        targetCefr: 'B1',
        dailyGoalMinutes: 30,
        mastery: .42,
        dailyProgress: 1,
        weeklyProgress: .25,
        dueReviews: 0,
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
      )
      ..questData = const [
        QuestData(code: 'daily_review', current: 5, target: 5, completed: true),
        QuestData(code: 'daily_xp', current: 50, target: 50, completed: true),
      ];
    await pumpWidgetWithLingoRoadScreenUtil(tester, homeApp(repository));
    await tester.pumpAndSettle();

    final progress = tester.widget<LinearProgressIndicator>(
      find.descendant(
        of: find.byKey(const Key('home_daily_progress')),
        matching: find.byType(LinearProgressIndicator),
      ),
    );

    expect(find.text('30 / 30 phút'), findsNothing);
    expect(find.byKey(const Key('home_daily_goal_row')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('home_daily_goal_row')),
        matching: find.byIcon(Icons.timer_outlined),
      ),
      findsOneWidget,
    );
    expect(find.text('Đã hoàn thành'), findsNWidgets(3));
    expect(progress.color, AppColors.success);
    expect(find.byKey(const Key('home_daily_xp_progress')), findsNothing);
  });

  testWidgets('Thanh tiến độ thụt vào so với grid của tiêu đề', (tester) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    final heroLeft = tester
        .getTopLeft(find.byKey(const Key('home_summary_hero')))
        .dx;
    final dailyPlanLeft = tester
        .getTopLeft(find.byKey(const Key('home_daily_plan')))
        .dx;
    final masteryProgress = find.byKey(const Key('home_mastery_progress'));
    final dailyProgress = find.byKey(const Key('home_daily_progress'));
    final questProgress = find.byKey(const Key('home_daily_xp_progress'));

    expect(tester.getTopLeft(masteryProgress).dx, greaterThan(heroLeft));
    expect(
      tester.getSize(masteryProgress).width,
      lessThan(
        tester.getSize(find.byKey(const Key('home_summary_hero'))).width,
      ),
    );
    expect(tester.getTopLeft(dailyProgress).dx, greaterThan(dailyPlanLeft));
    expect(tester.getTopLeft(questProgress).dx, greaterThan(dailyPlanLeft));
  });

  testWidgets('Home consolidates duplicate sections into a daily plan', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('home_daily_plan')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Kế hoạch hôm nay'), findsOneWidget);
    expect(find.text('Mục tiêu trong tuần'), findsNothing);
    expect(find.text('Nhiệm vụ hôm nay'), findsNothing);
    expect(find.text('Hoàn thành một bài học'), findsNothing);
    expect(find.text('Ôn tập 3 thẻ'), findsOneWidget);
    expect(find.text('Đạt 50 XP'), findsOneWidget);
    expect(find.byKey(const Key('home_review_action')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('home_ai_practice')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final practiceCard = tester.widget<AppCard>(
      find.descendant(
        of: find.byKey(const Key('home_ai_practice')),
        matching: find.byType(AppCard),
      ),
    );
    expect(practiceCard.color, AppTheme.light.colorScheme.surface);
    expect(find.text('Luyện phát âm'), findsOneWidget);
    expect(find.text('Gần đây'), findsNothing);
    expect(find.text('Chưa có bài học nào hoàn thành.'), findsNothing);
  });

  testWidgets('Nhiệm vụ là hàng phẳng, không lồng card trong kế hoạch', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    for (final cardKey in const [
      Key('home_daily_review_card'),
      Key('home_daily_xp_card'),
    ]) {
      final card = tester.widget<Container>(find.byKey(cardKey));
      final decoration = card.decoration;

      expect(decoration, isNull);
    }
  });

  testWidgets('Nhiệm vụ không lồng card ở dark mode', (tester) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository(), theme: AppTheme.dark),
    );
    await tester.pumpAndSettle();

    for (final cardKey in const [
      Key('home_daily_review_card'),
      Key('home_daily_xp_card'),
    ]) {
      final card = tester.widget<Container>(find.byKey(cardKey));
      final decoration = card.decoration;

      expect(decoration, isNull);
    }
  });

  testWidgets('Thẻ luyện phát âm dùng viền trung tính', (tester) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository()),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('home_ai_practice')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final card = tester.widget<AppCard>(
      find.descendant(
        of: find.byKey(const Key('home_ai_practice')),
        matching: find.byType(AppCard),
      ),
    );

    expect(card.borderColor, const Color(0xFFE6E1E0));
  });

  testWidgets('Thẻ luyện phát âm dùng viền trung tính ở dark mode', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      homeApp(FakeDashboardRepository(), theme: AppTheme.dark),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('home_ai_practice')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final card = tester.widget<AppCard>(
      find.descendant(
        of: find.byKey(const Key('home_ai_practice')),
        matching: find.byType(AppCard),
      ),
    );

    expect(card.borderColor, const Color(0xFF383838));
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
    'Chi tiết streak dark resolve indicator và stat icon theo primary',
    (tester) async {
      await pumpWidgetWithLingoRoadScreenUtil(
        tester,
        streakApp(FakeDashboardRepository(), theme: AppTheme.dark),
      );
      await tester.pumpAndSettle();

      final primary = AppTheme.dark.colorScheme.primary;
      expect(
        tester
            .widget<Icon>(find.byIcon(Icons.local_fire_department_rounded))
            .color,
        primary,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.emoji_events_rounded)).color,
        primary,
      );
    },
  );

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

  testWidgets('thẻ bài học hôm nay dùng primary container dễ đọc ở dark mode', (
    tester,
  ) async {
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      MultiProvider(
        providers: [
          Provider<AuthRepository?>.value(value: null),
          ChangeNotifierProvider<AppLanguageProvider>.value(
            value: languageProvider(),
          ),
          ChangeNotifierProvider<DashboardViewModel>(
            create: (_) => DashboardViewModel(FakeDashboardRepository()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.widget<Container>(
      find.byKey(const Key('home_today_lesson')),
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.color, AppTheme.dark.colorScheme.primaryContainer);
  });
}
