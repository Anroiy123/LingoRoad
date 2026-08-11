import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoroad_mobile/theme/app_theme.dart';

const lingoRoadDesignSize = Size(390, 844);
const lingoRoadGoldenRootKey = Key('lingoroad_golden_root');

Future<void>? _fontLoad;

Future<void> loadLingoRoadGoldenFonts() => _fontLoad ??= () async {
  final hankenLoader = FontLoader('HankenGrotesk')
    ..addFont(
      rootBundle.load('assets/fonts/HankenGrotesk-VariableFont_wght.ttf'),
    );
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait([hankenLoader.load(), materialIconsLoader.load()]);
}();

void expectRenderedTextSequence(Finder ancestor, String expected) {
  final actual = find
      .descendant(of: ancestor, matching: find.byType(Text))
      .evaluate()
      .map((element) => (element.widget as Text).data ?? '')
      .where((text) => text.isNotEmpty)
      .join(' ');

  expect(actual, expected);
}

void configureLingoRoadTestViewport(
  WidgetTester tester, {
  Size size = lingoRoadDesignSize,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;

  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> pumpLingoRoadGoldenSurface(
  WidgetTester tester, {
  required Widget child,
  required ThemeMode themeMode,
  Size size = lingoRoadDesignSize,
  double textScaleFactor = 1,
}) async {
  configureLingoRoadTestViewport(tester, size: size);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: lingoRoadDesignSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, screenUtilChild) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('vi'),
        theme: AppTheme.light.copyWith(platform: TargetPlatform.android),
        darkTheme: AppTheme.dark.copyWith(platform: TargetPlatform.android),
        themeMode: themeMode,
        builder: (context, materialChild) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: materialChild!,
        ),
        home: TickerMode(
          enabled: false,
          child: RepaintBoundary(key: lingoRoadGoldenRootKey, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

Future<void> pumpWidgetWithLingoRoadScreenUtil(
  WidgetTester tester,
  Widget child,
) {
  configureLingoRoadTestViewport(tester);
  return tester.pumpWidget(
    ScreenUtilInit(
      designSize: lingoRoadDesignSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, screenUtilChild) => child,
    ),
  );
}
