import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A circle drawn with short dashes (used for days with nothing logged).
class DashedCircle extends StatelessWidget {
  const DashedCircle({super.key, required this.color, this.child, this.dashes = 14, this.stroke = 1.6});

  final Color color;
  final Widget? child;
  final int dashes;
  final double stroke;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedCirclePainter(color: color, dashes: dashes, stroke: stroke),
    child: Center(child: child),
  );
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color, required this.dashes, required this.stroke});

  final Color color;
  final int dashes;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final step = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * step, step * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color || old.dashes != dashes;
}
