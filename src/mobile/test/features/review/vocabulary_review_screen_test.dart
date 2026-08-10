import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/review/data/review_repository.dart';
import 'package:lingoroad_mobile/features/review/domain/review_models.dart';
import 'package:lingoroad_mobile/features/review/presentation/review_view_model.dart';
import 'package:lingoroad_mobile/screens/vocabulary_review_screen.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../helpers/widget_test_harness.dart';

class _FakeReviewRepository implements ReviewRepository {
  var gradeCalls = 0;
  final cards = [
    ReviewCard(
      id: 'c1',
      front: 'Apple',
      back: 'Quả táo',
      due: DateTime.now(),
      state: 'new',
      reps: 0,
    ),
  ];

  @override
  Future<List<ReviewCard>> fetchDue() async => cards;

  @override
  Future<void> grade(
      {required ReviewCard card,
      required int rating,
      required String operationId}) async {
    gradeCalls++;
  }

  @override
  Future<void> createCard(String skillCode, String front, String back) async {}
}

AppLanguageProvider _language() {
  final vi = json
      .decode(File('assets/translations/vi.json').readAsStringSync()) as Map<String, dynamic>;
  final en = json
      .decode(File('assets/translations/en.json').readAsStringSync()) as Map<String, dynamic>;
  return AppLanguageProvider.test(
      translations: {AppLanguage.vi: vi, AppLanguage.en: en});
}

void main() {
  testWidgets('VocabularyReviewScreen displays card and marks as learned',
      (tester) async {
    final session = SessionController(MemorySessionStore('token'));
    await session.restore();
    final reviewRepo = _FakeReviewRepository();
    final l10n = _language();

    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<AppLanguageProvider>.value(value: l10n),
          ChangeNotifierProvider(create: (_) => ReviewViewModel(reviewRepo)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const VocabularyReviewScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Chạm để xem nghĩa'), findsOneWidget);

    // Flip the card by tapping front text
    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();

    expect(find.text('Quả táo'), findsOneWidget);
    expect(find.byKey(const Key('review_mark_learned_button')), findsOneWidget);
    expect(find.text('Đã thuộc'), findsOneWidget);

    // Tap Mark Learned button
    await tester.tap(find.byKey(const Key('review_mark_learned_button')));
    await tester.pumpAndSettle();

    expect(reviewRepo.gradeCalls, 1);
  });
}
