import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/auth/data/auth_repository.dart';
import 'package:lingoroad_mobile/features/auth/domain/user_profile.dart';
import 'package:lingoroad_mobile/features/progress/data/progress_repository.dart';
import 'package:lingoroad_mobile/features/progress/domain/progress_models.dart';
import 'package:lingoroad_mobile/core/theme/app_theme_provider.dart';
import 'package:lingoroad_mobile/screens/notification_settings_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/widget_test_harness.dart';

class _TestAuthRepository implements AuthRepository {
  @override Future<UserProfile> completeProfileSetup({required String name, required String targetCefr, required int dailyGoalMinutes}) => getProfile();
  var failUpdate = false;
  var updateCalls = 0;
  final profile = const UserProfile(
    id: 'u1',
    email: 'learner@example.com',
    name: 'Learner',
    targetCefr: 'B1',
    cefrLevel: 'A2',
    level: 2,
    badgesCount: 1,
    dailyGoalMinutes: 45,
    learningPurpose: 'Work',
    focusSkillIds: [1],
    studyReminderEnabled: true,
    reminderTime: '19:30',
    emailNotifications: true,
    appUpdates: true,
  );

  @override
  Future<UserProfile> getProfile() async => profile;

  @override
  Future<UserProfile> updateProfile(Map<String, Object?> values) async {
    updateCalls++;
    if (failUpdate) {
      throw const ApiException(code: 'offline', message: 'offline');
    }
    return profile;
  }

  @override
  Future<void> changePassword(
      {required String currentPassword, required String newPassword}) async {}

  @override
  Future<void> logout(String? refreshToken) async {}

  @override
  Future<AuthTokens> login(
          {required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<AuthTokens> register(
          {required String email, required String password, String? name}) =>
      throw UnimplementedError();
}

class _TestProgressRepository implements ProgressRepository {
  @override
  Future<List<MasteryRow>> mastery() async => const [];

  @override
  Future<List<SkillCatalogItem>> skills() async => const [];
}

AppLanguageProvider _language() {
  Map<String, dynamic> load(String path) =>
      json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return AppLanguageProvider.test(translations: {
    AppLanguage.vi: load('assets/translations/vi.json'),
    AppLanguage.en: load('assets/translations/en.json'),
  });
}

void main() {
  testWidgets(
      'NotificationSettingsScreen displays notifications, language and theme options',
      (tester) async {
    final repository = _TestAuthRepository();
    final session = SessionController(MemorySessionStore('access', 'refresh'));
    await session.restore();
    final themeProvider = AppThemeProvider();

    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      MultiProvider(
        providers: [
          Provider<AuthRepository>.value(value: repository),
          Provider<ProgressRepository>.value(value: _TestProgressRepository()),
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<AppLanguageProvider>.value(
              value: _language()),
          ChangeNotifierProvider<AppThemeProvider>.value(
              value: themeProvider),
        ],
        child: const MaterialApp(
          home: NotificationSettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Thông báo qua Email'), findsOneWidget);
    expect(find.text('Cập nhật ứng dụng'), findsOneWidget);
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    expect(find.text('Giao diện'), findsOneWidget);
    expect(find.text('Mặc định hệ thống'), findsOneWidget);

    // Open language bottom sheet
    await tester.tap(find.text('Ngôn ngữ'));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);

    // Open theme bottom sheet
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    expect(find.text('Dark'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(themeProvider.themeMode, ThemeMode.dark);
    expect(find.text('Dark'), findsWidgets);
  });
}
