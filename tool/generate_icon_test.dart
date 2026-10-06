// Renders the Nutriq app icon from the same painter the app uses.
//
//   flutter test tool/generate_icon_test.dart
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/widgets/nutriq_mark.dart';

Future<void> _render(String path, void Function(Canvas canvas, Size size) paint) async {
  const size = Size(1024, 1024);
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder), size);
  final image = await recorder.endRecording().toImage(1024, 1024);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('generate app icon PNGs', (tester) async {
    await tester.runAsync(() async {
      // iOS + legacy Android: full-bleed graphite with the mark.
      await _render('assets/icon/nutriq_icon.png', (canvas, size) {
        const NutriqMarkPainter(withBackground: true).paint(canvas, size);
      });
      // Android adaptive foreground: mark only, inside the 66% safe zone.
      await _render('assets/icon/nutriq_icon_foreground.png', (canvas, size) {
        canvas.translate(size.width * 0.25, size.height * 0.25);
        const NutriqMarkPainter().paint(canvas, size * 0.5);
      });
    });
  });
}
