import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/domain/user_profile.dart';
import 'package:lingoroad_mobile/features/auth/presentation/login_screen.dart';
import 'package:lingoroad_mobile/features/auth/presentation/profile_setup_screen.dart';
import 'package:lingoroad_mobile/features/auth/presentation/register_screen.dart';
import 'package:lingoroad_mobile/features/auth/presentation/splash_screen.dart';
import 'package:lingoroad_mobile/features/placement/data/placement_repository.dart';
import 'package:lingoroad_mobile/features/placement/domain/placement_models.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_intro_screen.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_question_screen.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_result_screen.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_status_error_screen.dart';
import 'package:lingoroad_mobile/features/placement/presentation/placement_view_model.dart';
import 'package:lingoroad_mobile/features/progress/data/progress_repository.dart';
import 'package:lingoroad_mobile/features/progress/domain/progress_models.dart';
import 'package:lingoroad_mobile/features/progress/presentation/progress_view_model.dart';
import 'package:lingoroad_mobile/features/review/data/review_repository.dart';
import 'package:lingoroad_mobile/features/review/domain/review_models.dart';
import 'package:lingoroad_mobile/features/review/presentation/review_view_model.dart';
import 'package:lingoroad_mobile/screens/main_shell.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../helpers/widget_test_harness.dart';

enum _FoundationSurface {
  splash,
  login,
  register,
  placementIntro,
  placementQuestion,
  placementStatusError,
  placementResult,
  profileSetup,
  mainShell,
}

extension on _FoundationSurface {
  String get goldenName => switch (this) {
    _FoundationSurface.splash => 'splash',
    _FoundationSurface.login => 'login',
    _FoundationSurface.register => 'register',
    _FoundationSurface.placementIntro => 'placement_intro',
    _FoundationSurface.placementQuestion => 'placement_question',
    _FoundationSurface.placementStatusError => 'placement_status_error',
    _FoundationSurface.placementResult => 'placement_result',
    _FoundationSurface.profileSetup => 'profile_setup',
    _FoundationSurface.mainShell => 'main_shell',
  };
}

class _AuthRepository implements AuthRepository {
  @override
  Future<UserProfile> completeProfileSetup({
    required String name,
    required String targetCefr,
    required int dailyGoalMinutes,
  }) => getProfile();

  @override
  Future<UserProfile> getProfile() async => const UserProfile(
    id: 'golden-user',
    email: 'learner@example.com',
    name: 'Learner',
    targetCefr: 'B2',
    cefrLevel: 'A2',
    level: 3,
    badgesCount: 2,
    profileSetupCompleted: true,
  );

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async => const AuthTokens(accessToken: 'token', refreshToken: 'refresh');

  @override
  Future<AuthTokens> register({
    required String email,
    required String password,
    String? name,
  }) async => const AuthTokens(accessToken: 'token', refreshToken: 'refresh');

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
}

class _PlacementRepository implements PlacementRepository {
  static const item = PlacementItem(
    id: 'item-1',
    type: 'mcq',
    stem: 'Choose the sentence that is grammatically correct.',
    options: [
      'She goes to school every day.',
      'She go to school every day.',
      'She going to school every day.',
      'She gone to school every day.',
    ],
  );

  static const placementResult = PlacementResult(
    theta: 0.8,
    se: 0.24,
    cefr: 'B1',
    itemsAnswered: 12,
    status: 'completed',
  );

  @override
  Future<bool> isCompleted() async => false;

  @override
  Future<PlacementStart> start() async =>
      const PlacementStart(sessionId: 'session-1', item: item);

  @override
  Future<PlacementStep> answer({
    required String sessionId,
    required String itemId,
    required String answer,
  }) async => const PlacementStep(done: true, theta: 0.8, se: 0.24, cefr: 'B1');

  @override
  Future<PlacementResult> result(String sessionId) async => placementResult;
}

class _ReviewRepository implements ReviewRepository {
  @override
  Future<List<ReviewCard>> fetchDue() async => const [];

  @override
  Future<void> grade({
    required ReviewCard card,
    required int rating,
    required String operationId,
  }) async {}

  @override
  Future<void> createCard(String skillCode, String front, String back) async {}
}

class _ProgressRepository implements ProgressRepository {
  @override
  Future<List<SkillCatalogItem>> skills() async => const [];

  @override
  Future<List<MasteryRow>> mastery() async => const [];
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
    currentLanguage: AppLanguage.vi,
  );
}

Future<Widget> _surface(_FoundationSurface surface) async {
  final session = SessionController(MemorySessionStore('token'));
  final auth = _AuthRepository();
  final placementRepository = _PlacementRepository();
  final placement = PlacementViewModel(placementRepository);
  final language = _language();

  if (surface == _FoundationSurface.placementQuestion ||
      surface == _FoundationSurface.placementResult) {
    await placement.start();
  }
  if (surface == _FoundationSurface.placementResult) {
    placement.selectAnswer(_PlacementRepository.item.options.first);
    await placement.submitAnswer();
  }

  final child = switch (surface) {
    _FoundationSurface.splash => const SplashScreen(),
    _FoundationSurface.login => const LoginScreen(),
    _FoundationSurface.register => const RegisterScreen(),
    _FoundationSurface.placementIntro => const PlacementIntroScreen(),
    _FoundationSurface.placementQuestion => const PlacementQuestionScreen(),
    _FoundationSurface.placementStatusError =>
      const PlacementStatusErrorScreen(),
    _FoundationSurface.placementResult => const PlacementResultScreen(),
    _FoundationSurface.profileSetup => const ProfileSetupScreen(),
    _FoundationSurface.mainShell => const MainShell(),
  };

  return MultiProvider(
    providers: [
      Provider<AuthRepository>.value(value: auth),
      ChangeNotifierProvider<SessionController>.value(value: session),
      ChangeNotifierProvider<AppLanguageProvider>.value(value: language),
      ChangeNotifierProvider<PlacementViewModel>.value(value: placement),
      ChangeNotifierProvider(
        create: (_) => ReviewViewModel(_ReviewRepository()),
      ),
      ChangeNotifierProvider(
        create: (_) => ProgressViewModel(_ProgressRepository()),
      ),
    ],
    child: child,
  );
}

void _expectInteractiveControlsAtLeast48(WidgetTester tester) {
  final controls = find.byWidgetPredicate(
    (widget) =>
        widget is FilledButton ||
        widget is OutlinedButton ||
        widget is TextButton ||
        widget is IconButton ||
        widget is TextFormField ||
        widget is SegmentedButton ||
        widget is Slider ||
        widget is NavigationDestination,
  );
  for (var index = 0; index < controls.evaluate().length; index++) {
    final finder = controls.at(index);
    final size = tester.getSize(finder);
    expect(
      size.width,
      greaterThanOrEqualTo(48),
      reason: '${finder.evaluate().single.widget.runtimeType} width',
    );
    expect(
      size.height,
      greaterThanOrEqualTo(48),
      reason: '${finder.evaluate().single.widget.runtimeType} height',
    );
  }
}

void main() {
  setUpAll(loadLingoRoadGoldenFonts);

  for (final surface in _FoundationSurface.values) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final brightness = mode == ThemeMode.light ? 'light' : 'dark';
      testWidgets('${surface.goldenName} $brightness golden', (tester) async {
        await pumpLingoRoadGoldenSurface(
          tester,
          child: await _surface(surface),
          themeMode: mode,
        );

        await expectLater(
          find.byKey(lingoRoadGoldenRootKey),
          matchesGoldenFile('foundation/${surface.goldenName}_$brightness.png'),
        );
      });
    }
  }

  const renderingProfiles = [
    (name: 'compact-320', size: Size(320, 844), textScale: 1.0),
    (name: 'wide-600', size: Size(600, 844), textScale: 1.0),
    (name: 'text-scale-1.3', size: Size(390, 844), textScale: 1.3),
  ];
  for (final profile in renderingProfiles) {
    testWidgets(
      'all foundation surfaces render without overflow at ${profile.name}',
      (tester) async {
        for (final surface in _FoundationSurface.values) {
          await pumpLingoRoadGoldenSurface(
            tester,
            child: await _surface(surface),
            themeMode: ThemeMode.light,
            size: profile.size,
            textScaleFactor: profile.textScale,
          );
          expect(tester.takeException(), isNull, reason: surface.goldenName);
        }
      },
    );
  }

  testWidgets('foundation interactive controls are at least 48 by 48', (
    tester,
  ) async {
    for (final surface in _FoundationSurface.values) {
      await pumpLingoRoadGoldenSurface(
        tester,
        child: await _surface(surface),
        themeMode: ThemeMode.light,
      );
      _expectInteractiveControlsAtLeast48(tester);
    }
  });

  for (final surface in [
    _FoundationSurface.login,
    _FoundationSurface.register,
  ]) {
    testWidgets('${surface.goldenName} uses dark semantic surface and text', (
      tester,
    ) async {
      await pumpLingoRoadGoldenSurface(
        tester,
        child: await _surface(surface),
        themeMode: ThemeMode.dark,
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppColorsDark.background);
      final heading = tester.widget<Text>(
        find.text(
          surface == _FoundationSurface.login
              ? 'Chào mừng trở lại'
              : 'Tạo tài khoản',
        ),
      );
      expect(heading.style?.color, AppColorsDark.text);
      final logo = tester.widget<Image>(find.byType(Image).first);
      expect(
        (logo.image as AssetImage).assetName,
        'assets/images/logo.png',
        reason: 'dark surfaces require the bundled light-on-dark logo',
      );
    });
  }

  testWidgets('shared foundation components resolve dark semantic colors', (
    tester,
  ) async {
    await pumpLingoRoadGoldenSurface(
      tester,
      child: await _surface(_FoundationSurface.mainShell),
      themeMode: ThemeMode.dark,
    );
    final brand = tester.widget<Text>(find.text('lingoRoad'));
    expect(brand.style?.color, AppColorsDark.primary);
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(avatar.backgroundColor, AppColorsDark.surfaceHigh);

    await pumpLingoRoadGoldenSurface(
      tester,
      child: await _surface(_FoundationSurface.placementQuestion),
      themeMode: ThemeMode.dark,
    );
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.color, AppColorsDark.primary);
    expect(progress.backgroundColor, AppColorsDark.surfaceHigh);
  });
}
