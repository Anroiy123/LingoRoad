import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_harness.dart';

Future<Uint8List> _rasterBytes(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final raster = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  return raster!;
}

Widget _iconCell(Key key, IconData icon) => RepaintBoundary(
  key: key,
  child: ColoredBox(
    color: Colors.white,
    child: Center(child: Icon(icon, size: 48, color: Colors.black)),
  ),
);

void main() {
  setUpAll(loadLingoRoadGoldenFonts);

  testWidgets('bundled Material Icons render distinct non-tofu rasters', (
    tester,
  ) async {
    const mailKey = Key('material-icon-mail');
    const lockKey = Key('material-icon-lock');
    const tofuKey = Key('material-icon-missing-glyph');

    await pumpLingoRoadGoldenSurface(
      tester,
      themeMode: ThemeMode.light,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconCell(mailKey, Icons.mail_outlined),
          _iconCell(lockKey, Icons.lock_outline_rounded),
          _iconCell(
            tofuKey,
            const IconData(0x10ffff, fontFamily: 'MaterialIcons'),
          ),
        ].map((icon) => SizedBox(width: 64, height: 64, child: icon)).toList(),
      ),
    );

    final mailRaster = await _rasterBytes(tester, mailKey);
    final lockRaster = await _rasterBytes(tester, lockKey);
    final tofuRaster = await _rasterBytes(tester, tofuKey);

    expect(mailRaster, isNot(equals(tofuRaster)));
    expect(lockRaster, isNot(equals(tofuRaster)));
    expect(mailRaster, isNot(equals(lockRaster)));
  });
}
