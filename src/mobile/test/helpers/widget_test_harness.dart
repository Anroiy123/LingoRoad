import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const lingoRoadDesignSize = Size(390, 844);

void configureLingoRoadTestViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = lingoRoadDesignSize;

  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
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
