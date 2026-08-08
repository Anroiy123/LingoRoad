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
import 'package:lingoroad_mobile/screens/review_screen.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../helpers/widget_test_harness.dart';

class FakeReviewRepository implements ReviewRepository {
  @override
  Future<List<ReviewCard>> fetchDue() async => const [];
  @override
  Future<void> grade({required ReviewCard card, required int rating, required String operationId}) async {}
  @override
  Future<void> createCard(String skillCode, String front, String back) async {}
}

AppLanguageProvider _language() {
  final vi = json.decode(File('assets/translations/vi.json').readAsStringSync()) as Map<String, dynamic>;
  final en = json.decode(File('assets/translations/en.json').readAsStringSync()) as Map<String, dynamic>;
  return AppLanguageProvider.test(translations: {AppLanguage.vi: vi, AppLanguage.en: en});
}

void main() {
  testWidgets('ReviewScreen renders translated selection texts', (tester) async {
    final session = SessionController(MemorySessionStore('token'));
    await session.restore();
    final review = FakeReviewRepository();
    final l10n = _language();

    // Verify key translation works programmatically
    expect(l10n.translate('review.selection.title'), 'Lựa chọn ôn tập');
    expect(l10n.translate('review.selection.question_title'), 'Ôn tập câu hỏi');

    await pumpWidgetWithLingoRoadScreenUtil(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<AppLanguageProvider>.value(value: l10n),
          ChangeNotifierProvider(create: (_) => ReviewViewModel(review)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: ReviewScreen(active: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lựa chọn ôn tập'), findsOneWidget);
    expect(find.text('Ôn tập câu hỏi'), findsOneWidget);
    expect(find.text('Ôn tập từ vựng'), findsOneWidget);
  });
}
