import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/format.dart';
import '../app/theme.dart';
import '../domain/models/user_profile.dart';

/// Nutriq's signature visual: a 240° open gauge where the personal goal is a
/// *band* on the arc (a range, not a pass/fail number).
class CalorieGauge extends StatelessWidget {
  const CalorieGauge({super.key, required this.calories, required this.range, this.size = 260});

  final double calories;
  final CalorieRange? range;
  final double size;

  /// Where the top of the range sits on the arc.
  static const _rangeMaxPosition = 0.8;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final r = range;
    final scaleMax = r == null ? null : r.max / _rangeMaxPosition;
    final target = scaleMax == null ? 0.0 : (calories / scaleMax).clamp(0.0, 1.0);

    return Semantics(
      label: r == null
          ? 'About ${fmtKcal(calories)} calories eaten today, estimated. No calorie goal set.'
          : 'About ${fmtKcal(calories)} calories eaten today, estimated. '
                'Goal range ${fmtKcal(r.min)} to ${fmtKcal(r.max)}.',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 750),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => SizedBox(
          width: size,
          height: size * 0.86,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GaugePainter(
                    progress: progress,
                    rangeStart: scaleMax == null ? null : r!.min / scaleMax,
                    rangeEnd: scaleMax == null ? null : _rangeMaxPosition,
                  ),
                ),
              ),
              Positioned(
                top: size * 0.32,
                child: ExcludeSemantics(
                  child: Column(
                    children: [
                      FittedBox(child: Text(fmtKcal(calories), style: NqText.heroNumber)),
                      const SizedBox(height: 6),
                      Text('kcal eaten · est.', style: NqText.footnote),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.progress, required this.rangeStart, required this.rangeEnd});

  final double progress;
  final double? rangeStart;
  final double? rangeEnd;

  static const _start = 150 * math.pi / 180;
  static const _sweep = 240 * math.pi / 180;
  static const _stroke = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.width / 2);
    final radius = size.width / 2 - _stroke / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);

    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _start, _sweep, false, stroke(NqColors.raised, _stroke));

    // Goal band, drawn just outside the track.
    if (rangeStart != null && rangeEnd != null) {
      final bandRect = Rect.fromCircle(center: center, radius: radius + _stroke / 2 + 7);
      canvas.drawArc(
        bandRect,
        _start + _sweep * rangeStart!,
        _sweep * (rangeEnd! - rangeStart!),
        false,
        stroke(NqColors.sage.withValues(alpha: 0.6), 5),
      );
    }

    if (progress > 0) {
      final withinEnd = rangeEnd == null ? progress : math.min(progress, rangeEnd!);
      canvas.drawArc(rect, _start, _sweep * withinEnd, false, stroke(NqColors.sage, _stroke));
      if (rangeEnd != null && progress > rangeEnd!) {
        canvas.drawArc(
          rect,
          _start + _sweep * rangeEnd!,
          _sweep * (progress - rangeEnd!),
          false,
          stroke(NqColors.amber, _stroke),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.rangeStart != rangeStart || old.rangeEnd != rangeEnd;
}

/// One-line, non-judgmental status under the gauge.
String gaugeStatus(double calories, CalorieRange? range) {
  if (range == null) return 'No calorie goal set';
  final kcal = calories.round();
  if (kcal < range.min) return '≈ ${fmtKcal(range.min - kcal)} kcal to your range';
  if (kcal <= range.max) return 'Within your ${fmtKcal(range.min)}–${fmtKcal(range.max)} range';
  return '≈ ${fmtKcal(kcal - range.max)} kcal above your range';
}
