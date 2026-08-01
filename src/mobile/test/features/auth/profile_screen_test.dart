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
import 'package:lingoroad_mobile/screens/profile_screen.dart';
import 'package:provider/provider.dart';

import '../../helpers/widget_test_harness.dart';

class _ProfileRepository implements AuthRepository {
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
    emailNotifications: false,
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
  Future<AuthTokens> login({required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<AuthTokens> register(
          {required String email, required String password, String? name}) =>
      throw UnimplementedError();
}

class _ProgressRepository implements ProgressRepository {
  @override
  Future<List<MasteryRow>> mastery() async => const [];
  @override
  Future<List<SkillCatalogItem>> skills() async => const [
        SkillCatalogItem(
            id: 1,
            code: 'grammar.present',
            name: 'Present tense',
            nameVi: 'Thì hiện tại',
            category: 'grammar',
            parentId: 10),
      ];
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
  testWidgets('profile hiển thị dữ liệu API và rollback toggle khi save lỗi',
      (tester) async {
    final repository = _ProfileRepository()..failUpdate = true;
    final session = SessionController(MemorySessionStore('access', 'refresh'));
    await session.restore();
    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      MultiProvider(
        providers: [
          Provider<AuthRepository>.value(value: repository),
          Provider<ProgressRepository>.value(value: _ProgressRepository()),
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('45 phút / ngày'), findsOneWidget);
    expect(find.text('B1'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    final reminder = find.byType(Switch).first;
    expect(tester.widget<Switch>(reminder).value, isTrue);
    await tester.tap(reminder);
    await tester.pumpAndSettle();
    expect(repository.updateCalls, 1);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    expect(
        find.text('Không thể lưu thay đổi. Vui lòng thử lại.'), findsOneWidget);
  });
}
