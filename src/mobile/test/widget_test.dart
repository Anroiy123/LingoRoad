import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/session/session_controller.dart';
import 'package:lingoroad_mobile/core/session/session_store.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/screens/main_shell.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:lingoroad_mobile/widgets/common.dart';
import 'package:provider/provider.dart';

AppLanguageProvider loadTestLanguageProvider() {
  final viContent = File('assets/translations/vi.json').readAsStringSync();
  final enContent = File('assets/translations/en.json').readAsStringSync();
  final viMap = json.decode(viContent) as Map<String, dynamic>;
  final enMap = json.decode(enContent) as Map<String, dynamic>;
  return AppLanguageProvider.test(
    translations: {
      AppLanguage.vi: viMap,
      AppLanguage.en: enMap,
    },
    currentLanguage: AppLanguage.vi,
  );
}

void main() {
  testWidgets('hiển thị đủ năm tab chính', (tester) async {
    final session = SessionController(MemorySessionStore('token'));
    await session.restore();
    final l10n = loadTestLanguageProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider<AppLanguageProvider>.value(value: l10n),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MainShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Học'), findsOneWidget);
    expect(find.text('Lộ trình'), findsOneWidget);
    expect(find.text('Ôn tập'), findsOneWidget);
    expect(find.text('Tiến độ'), findsOneWidget);
    expect(find.text('Hồ sơ'), findsOneWidget);
  });

  testWidgets('progress giới hạn giá trị', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppProgress(value: 2))),
    );
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 1);
  });
}
