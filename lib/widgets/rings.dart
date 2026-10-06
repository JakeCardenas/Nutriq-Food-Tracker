import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/format.dart';
import '../app/theme.dart';
import '../domain/models/nutrition.dart';
import '../domain/models/user_profile.dart';
import '../domain/references.dart';
import 'labels.dart';
import 'surfaces.dart';

/// Circular progress that animates whenever its value changes.
class AnimatedRing extends StatelessWidget {
  const AnimatedRing({
    super.key,
    required this.progress,
    required this.color,
    this.size = 64,
    this.stroke = 7,
    this.overColor,
    this.child,
  });

  /// 0..1 (values above 1 are drawn full and tinted with [overColor]).
  final double progress;
  final Color color;
  final Color? overColor;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final over = progress > 1 && overColor != null;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.clamp(0.0, 1.0)),
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(value: value, color: over ? overColor! : color, stroke: stroke),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color, required this.stroke});

  final double value;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = NqColors.track);
    if (value > 0) canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.stroke != stroke;
}

/// The day's calorie summary: eaten vs. the goal range, with a black ring.
class CalorieSummaryCard extends StatelessWidget {
  const CalorieSummaryCard({super.key, required this.calories, required this.range, this.onTap});

  final double calories;
  final CalorieRange? range;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = range;
    final eaten = calories.round();
    final progress = r == null ? 0.0 : calories / r.max;
    final status = r == null
        ? 'No calorie goal set'
        : eaten < r.min
        ? '≈ ${fmtKcal(r.min - eaten)} to your range'
        : eaten <= r.max
        ? 'Within your range'
        : '≈ ${fmtKcal(eaten - r.max)} above your range';
    return NqCard(
      onTap: onTap,
      semanticLabel: 'About ${fmtKcal(eaten)} calories eaten, estimated. $status.',
      padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
      child: Row(
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(fmtKcal(eaten), style: NqText.heroNumber),
                        Text(
                          r == null ? '' : '/${fmtKcal(r.min)}–${fmtKcal(r.max)}',
                          style: NqText.headline.copyWith(color: NqColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Calories eaten · est.', style: NqText.callout.copyWith(color: NqColors.ink)),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: NqText.footnote.copyWith(
                      color: r != null && eaten > r.max ? NqColors.aboveRange : NqColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedRing(
            progress: progress,
            color: NqColors.ink,
            overColor: NqColors.aboveRange,
            size: 96,
            stroke: 9,
            child: const Icon(Icons.local_fire_department_rounded, color: NqColors.ink, size: 26),
          ),
        ],
      ),
    );
  }
}

/// Three macro cards with coloured rings (protein, carbs, fat).
class MacroRingRow extends StatelessWidget {
  const MacroRingRow({super.key, required this.totals, required this.references});

  final NutritionTotals totals;
  final MacroReferences references;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: MacroRingCard(macro: Macro.protein, grams: totals.protein, reference: references.protein),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: MacroRingCard(macro: Macro.carbs, grams: totals.carbs, reference: references.carbs),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: MacroRingCard(macro: Macro.fat, grams: totals.fat, reference: references.fat),
      ),
    ],
  );
}

class MacroRingCard extends StatelessWidget {
  const MacroRingCard({super.key, required this.macro, required this.grams, required this.reference});

  final Macro macro;
  final double grams;
  final int? reference;

  @override
  Widget build(BuildContext context) {
    final ref = reference;
    return Semantics(
      label: '${macro.label}: about ${grams.round()} grams${ref == null ? '' : ' of a $ref gram reference'}, estimated',
      excludeSemantics: true,
      child: NqCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${grams.round()}g', style: NqText.metric),
                  if (ref != null) Text('/${ref}g', style: NqText.caption.copyWith(fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('${macro.label} eaten', style: NqText.caption, maxLines: 1),
            ),
            const SizedBox(height: 14),
            Center(
              child: AnimatedRing(
                progress: ref == null || ref == 0 ? 0 : grams / ref,
                color: macro.color,
                size: 62,
                stroke: 7,
                child: Icon(macro.icon, size: 20, color: macro.color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
