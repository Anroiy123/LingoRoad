import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/progress/data/progress_repository.dart';
import 'package:lingoroad_mobile/features/progress/domain/progress_models.dart';
import 'package:lingoroad_mobile/features/progress/presentation/progress_view_model.dart';
import 'package:lingoroad_mobile/features/review/data/review_repository.dart';
import 'package:lingoroad_mobile/features/review/domain/review_models.dart';
import 'package:lingoroad_mobile/features/review/presentation/review_view_model.dart';
import 'package:lingoroad_mobile/screens/main_shell.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../helpers/widget_test_harness.dart';

class CountingReviewRepository implements ReviewRepository {
  int calls = 0;
  @override
  Future<List<ReviewCard>> fetchDue() async {
    calls++;
    return const [];
  }

  @override
  Future<void> grade(
      {required ReviewCard card,
      required int rating,
      required String operationId}) async {}
}

class CountingProgressRepository implements ProgressRepository {
  int skillCalls = 0;
  @override
  Future<List<SkillCatalogItem>> skills() async {
    skillCalls++;
    return const [];
  }

  @override
  Future<List<MasteryRow>> mastery() async => const [];
}

AppLanguageProvider _language() {
  final vi = json.decode(File('assets/translations/vi.json').readAsStringSync())
      as Map<String, dynamic>;
  final en = json.decode(File('assets/translations/en.json').readAsStringSync())
      as Map<String, dynamic>;
  return AppLanguageProvider.test(
      translations: {AppLanguage.vi: vi, AppLanguage.en: en});
}

void main() {
  testWidgets(
      'Review and Progress fetch only when their respective tab is selected',
      (tester) async {
    final session = SessionController(MemorySessionStore('token'));
    await session.restore();
    final review = CountingReviewRepository();
    final progress = CountingProgressRepository();
    await pumpWidgetWithLingoRoadScreenUtil(
        tester,
        MultiProvider(providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<AppLanguageProvider>.value(value: _language()),
          ChangeNotifierProvider(create: (_) => ReviewViewModel(review)),
          ChangeNotifierProvider(create: (_) => ProgressViewModel(progress)),
        ], child: MaterialApp(theme: AppTheme.light, home: const MainShell())));
    await tester.pumpAndSettle();
    expect(review.calls, 0);
    expect(progress.skillCalls, 0);
    await tester.tap(find.text('Ôn tập'));
    await tester.pumpAndSettle();
    expect(review.calls, 1);
    expect(progress.skillCalls, 0);
    await tester.tap(find.text('Tiến độ'));
    await tester.pumpAndSettle();
    expect(progress.skillCalls, 1);
  });
}
