// Renders the Nutriq launcher icon layers from NutriqAppIconPainter.
//
//   flutter test tool/generate_icon_test.dart
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/widgets/nutriq_mark.dart';

Future<void> _render(String path, NutriqAppIconPainter painter) async {
  const size = Size(1024, 1024);
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(1024, 1024);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('generate app icon PNGs', (tester) async {
    await tester.runAsync(() async {
      // iOS + legacy Android: square, full-bleed; the OS applies its own mask.
      await _render('assets/icon/nutriq_icon.png', const NutriqAppIconPainter());

      // Android adaptive icon. flutter_launcher_icons insets the foreground by
      // 16 %, so this image spans the visible area; 0.94 keeps the corner
      // brackets inside the 66 dp safe zone on every mask shape.
      await _render(
        'assets/icon/nutriq_icon_foreground.png',
        const NutriqAppIconPainter(layer: NutriqIconLayer.foreground, artworkScale: 0.94),
      );
      // The background layer is 108 dp but only the middle 72 dp shows, so the
      // gradient is compressed to keep the full yellow-to-red range visible.
      await _render(
        'assets/icon/nutriq_icon_background.png',
        const NutriqAppIconPainter(layer: NutriqIconLayer.background, gradientScale: 72 / 108),
      );
    });
  });
}
