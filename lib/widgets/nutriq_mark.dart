import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// The Nutriq mark: an open gauge ring with a descender, forming a "q".
/// Also used to render the app icon (see tool/generate_icon_test.dart).
class NutriqMark extends StatelessWidget {
  const NutriqMark({super.key, this.size = 72, this.withBackground = false});

  final double size;
  final bool withBackground;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: NutriqMarkPainter(withBackground: withBackground)),
  );
}

class NutriqMarkPainter extends CustomPainter {
  const NutriqMarkPainter({this.withBackground = false});

  final bool withBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (withBackground) {
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.2, -0.3),
            radius: 1.1,
            colors: [Color(0xFF202226), NqColors.background],
          ).createShader(rect),
      );
    }

    final scale = withBackground ? 0.62 : 1.0;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-s / 2, -s / 2);

    final stroke = s * 0.13;
    final center = Offset(s * 0.44, s * 0.42);
    final radius = s * 0.27;
    final ring = Paint()
      ..color = NqColors.sage
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // Ring that starts at its rightmost point (where the descender joins) and
    // runs clockwise, leaving a gap at the top-right like an unfinished gauge.
    const gap = 75 * math.pi / 180;
    const sweep = 2 * math.pi - gap;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 0, sweep, false, ring);

    // Descender that turns the ring into a "q", flowing out of the arc's start.
    final x = center.dx + radius;
    canvas.drawLine(Offset(x, center.dy), Offset(x, center.dy + s * 0.46), ring);

    // Amber "progress head" at the end of the arc.
    const dotAngle = sweep;
    canvas.drawCircle(
      center + Offset(math.cos(dotAngle), math.sin(dotAngle)) * radius,
      stroke * 0.36,
      Paint()..color = NqColors.amber,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(NutriqMarkPainter old) => old.withBackground != withBackground;
}
