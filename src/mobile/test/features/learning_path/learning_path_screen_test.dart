import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/core/network/api_exception.dart';
import 'package:lingoroad_mobile/core/utils/app_localization.dart';
import 'package:lingoroad_mobile/features/learning_path/data/learning_path_repository.dart';
import 'package:lingoroad_mobile/features/learning_path/domain/learning_path_models.dart';
import 'package:lingoroad_mobile/features/learning_path/presentation/learning_path_view_model.dart';
import 'package:lingoroad_mobile/screens/learning_path_screen.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

const widgetStep = LearningPathStep(
  code: 'grammar.present-simple',
  name: 'Present simple',
  nameVi: 'Thì hiện tại đơn',
  cefr: 'A2',
  mastery: 0.35,
  reason: 'below_threshold',
);

class ScreenLearningPathRepository implements LearningPathRepository {
  List<LearningPathStep> result = const [widgetStep];
  Object? error;

  @override
  Future<List<LearningPathStep>> fetch({int limit = 10}) async {
    if (error != null) {
      throw error!;
    }
    return result;
  }
}

AppLanguageProvider loadLanguageProvider() {
  final vi = json.decode(
    File('assets/translations/vi.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final en = json.decode(
    File('assets/translations/en.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return AppLanguageProvider.test(
    translations: {
      AppLanguage.vi: vi,
      AppLanguage.en: en,
    },
  );
}

Widget buildScreen(ScreenLearningPathRepository repository) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppLanguageProvider>.value(
        value: loadLanguageProvider(),
      ),
      ChangeNotifierProvider<LearningPathViewModel>(
        create: (_) => LearningPathViewModel(repository),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: LearningPathScreen()),
    ),
  );
}

void main() {
  testWidgets('hiển thị dữ liệu thật và không còn XP/streak mock',
      (tester) async {
    await tester.pumpWidget(buildScreen(ScreenLearningPathRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Thì hiện tại đơn'), findsOneWidget);
    expect(find.text('A2 · Cần luyện thêm'), findsOneWidget);
    expect(find.text('1 kỹ năng được đề xuất'), findsOneWidget);
    expect(find.textContaining('XP'), findsNothing);
    expect(find.text('12'), findsNothing);
  });

  testWidgets('hiển thị empty state', (tester) async {
    final repository = ScreenLearningPathRepository()..result = const [];

    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('learning_path_empty')), findsOneWidget);
    expect(find.text('Lộ trình hiện đã hoàn tất'), findsOneWidget);
  });

  testWidgets('hiển thị lỗi và retry thành công', (tester) async {
    final repository = ScreenLearningPathRepository()
      ..error = const ApiException(
        code: 'network_unavailable',
        message: 'offline',
      );

    await tester.pumpWidget(buildScreen(repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('learning_path_error')), findsOneWidget);

    repository.error = null;
    await tester.tap(find.byKey(const Key('learning_path_retry')));
    await tester.pumpAndSettle();

    expect(find.text('Thì hiện tại đơn'), findsOneWidget);
  });
}
