import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:lingoroad_mobile/features/dashboard/domain/dashboard_models.dart';
import 'package:lingoroad_mobile/features/dashboard/presentation/dashboard_session_provider.dart';
import 'package:lingoroad_mobile/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:provider/provider.dart';

DashboardData _dashboard(String name) => DashboardData(
      name: name,
      currentCefr: 'A2',
      targetCefr: 'B1',
      dailyGoalMinutes: 20,
      mastery: .5,
      dailyProgress: .2,
      weeklyProgress: .1,
      dueReviews: 0,
      completedLessons: 0,
      xp: 0,
      coins: 0,
      currentStreak: 0,
      longestStreak: 0,
      activeDates: const [],
      recentActivity: const [],
    );

const _quests = [
  QuestData(code: 'daily_lesson', current: 0, target: 1, completed: false),
];

class _SessionDashboardRepository implements DashboardRepository {
  _SessionDashboardRepository(
    this._session, {
    this.oldDashboard,
    this.oldQuests,
  });

  final SessionController _session;
  final Completer<DashboardData>? oldDashboard;
  final Completer<List<QuestData>>? oldQuests;
  final List<String?> dashboardTokens = [];

  @override
  Future<DashboardData> dashboard() {
    final token = _session.token;
    dashboardTokens.add(token);
    if (token == 'token-old') {
      return oldDashboard?.future ?? Future.value(_dashboard('Old learner'));
    }
    if (token == 'token-new') {
      return Future.value(_dashboard('New learner'));
    }
    throw StateError('Unexpected dashboard request without a test session.');
  }

  @override
  Future<List<QuestData>> quests() {
    if (_session.token == 'token-old') {
      return oldQuests?.future ?? Future.value(_quests);
    }
    if (_session.token == 'token-new') {
      return Future.value(_quests);
    }
    throw StateError('Unexpected quest request without a test session.');
  }
}

Future<void> _authenticateCompleted(
  SessionController session,
  String token,
) async {
  await session.authenticate(
    token,
    refreshToken: 'refresh-$token',
    checkPlacement: false,
  );
  session.markPlacementCompleted();
}

void main() {
  late SessionController session;

  setUp(() {
    session = SessionController(MemorySessionStore());
  });

  testWidgets(
      'Dashboard provider tạo state mới cho account mới không cần pull-to-refresh',
      (tester) async {
    final repository = _SessionDashboardRepository(session);
    await tester.runAsync(() => _authenticateCompleted(session, 'token-old'));
    final oldGeneration = session.sessionGeneration;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          Provider<DashboardRepository>.value(value: repository),
          dashboardViewModelProvider(),
        ],
        child: MaterialApp(
          home: Consumer<DashboardViewModel>(
            builder: (context, viewModel, child) => Text(
              '${viewModel.sessionGeneration}:'
              '${viewModel.dashboard?.name ?? viewModel.state.name}',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('$oldGeneration:Old learner'), findsOneWidget);

    await tester.runAsync(() async {
      await session.logout();
      await _authenticateCompleted(session, 'token-new');
    });
    expect(session.sessionGeneration, isNot(oldGeneration));
    await tester.pumpAndSettle();

    expect(
      find.text('${session.sessionGeneration}:New learner'),
      findsOneWidget,
    );
    expect(repository.dashboardTokens, ['token-old', 'token-new']);
  });

  testWidgets(
      'response Dashboard cũ không ghi đè account mới trên cùng provider',
      (tester) async {
    final oldDashboard = Completer<DashboardData>();
    final oldQuests = Completer<List<QuestData>>();
    final repository = _SessionDashboardRepository(
      session,
      oldDashboard: oldDashboard,
      oldQuests: oldQuests,
    );
    await tester.runAsync(() => _authenticateCompleted(session, 'token-old'));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          Provider<DashboardRepository>.value(value: repository),
          dashboardViewModelProvider(),
        ],
        child: MaterialApp(
          home: Consumer<DashboardViewModel>(
            builder: (context, viewModel, child) => Text(
              '${viewModel.sessionGeneration}:'
              '${viewModel.dashboard?.name ?? viewModel.state.name}',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(repository.dashboardTokens, ['token-old']);
    expect(find.text('${session.sessionGeneration}:loading'), findsOneWidget);

    await tester.runAsync(() async {
      await session.logout();
      await _authenticateCompleted(session, 'token-new');
    });
    await tester.pumpAndSettle();
    expect(
      find.text('${session.sessionGeneration}:New learner'),
      findsOneWidget,
    );

    oldDashboard.complete(_dashboard('Old learner'));
    oldQuests.complete(_quests);
    await tester.pumpAndSettle();

    expect(
      find.text('${session.sessionGeneration}:New learner'),
      findsOneWidget,
    );
    expect(repository.dashboardTokens, ['token-old', 'token-new']);
  });
}
