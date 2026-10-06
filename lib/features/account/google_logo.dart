import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The four-colour "G" used on "Continue with Google" buttons. Before a public
/// release, swap in Google's official branding asset per their guidelines.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _GooglePainter()),
  );
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.2;
    final rect = Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s / 2 - stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    double rad(double deg) => deg * math.pi / 180;
    canvas
      ..drawArc(rect, rad(-40), rad(-95), false, paint..color = const Color(0xFFEA4335))
      ..drawArc(rect, rad(-135), rad(-90), false, paint..color = const Color(0xFFFBBC05))
      ..drawArc(rect, rad(-225), rad(-95), false, paint..color = const Color(0xFF34A853))
      ..drawArc(rect, rad(40), rad(-80), false, paint..color = const Color(0xFF4285F4))
      ..drawRect(
        Rect.fromLTWH(s / 2, s / 2 - stroke / 2, s / 2 - stroke * 0.1, stroke),
        Paint()..color = const Color(0xFF4285F4),
      );
  }

  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}
