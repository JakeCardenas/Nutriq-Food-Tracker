import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/format.dart';
import '../../app/theme.dart';
import '../../domain/models/user_profile.dart';
import '../../services/coach/coach_service.dart' show DaySummary;

/// Seven daily calorie bars, each split by where the energy came from
/// (protein, carbs, fat), drawn against the goal range. Tap a bar to open that day.
class WeekChart extends StatelessWidget {
  const WeekChart({super.key, required this.days, required this.range, required this.selected, required this.onSelect});

  final List<DaySummary> days;
  final CalorieRange? range;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  static const _chartHeight = 150.0;

  @override
  Widget build(BuildContext context) {
    final maxKcal = days.map((d) => d.totals.calories).fold<double>(0, math.max);
    final scaleMax = math.max(1500.0, math.max(maxKcal, (range?.max ?? 0).toDouble()) * 1.12);
    double h(num kcal) => _chartHeight * (kcal / scaleMax).clamp(0.0, 1.0);

    return Column(
      children: [
        SizedBox(
          height: _chartHeight,
          child: Stack(
            children: [
              if (range != null) ...[_GoalLine(bottom: h(range!.max)), _GoalLine(bottom: h(range!.min))],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in days)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: d.day == selected,
                        label:
                            '${longDate(d.day)}: '
                            '${d.mealCount == 0 ? 'nothing logged' : 'about ${fmtKcal(d.totals.calories)} calories'}',
                        onTap: () => onSelect(d.day),
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onSelect(d.day);
                          },
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: d.day == selected || d.mealCount == 0 ? 1 : 0.55,
                              child: _StackedBar(
                                summary: d,
                                height: d.mealCount == 0 ? 4 : math.max(8, h(d.totals.calories)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: NqSpace.sm),
        Row(
          children: [
            for (final d in days)
              Expanded(
                // Read as one button by VoiceOver, like Today's week strip.
                child: Semantics(
                  button: true,
                  selected: d.day == selected,
                  onTap: () => onSelect(d.day),
                  label:
                      '${longDate(d.day)}'
                      '${d.mealCount > 0 ? ', about ${fmtKcal(d.totals.calories)} calories' : ', nothing logged'}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(d.day),
                    child: Column(
                      children: [
                        Text(weekdayShort(d.day), style: NqText.caption),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: d.day == selected ? NqColors.inkSoft : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${d.day.day}',
                            style: NqText.numberSmall.copyWith(
                              fontSize: 14,
                              color: d.day == selected ? NqColors.onInk : NqColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _GoalLine extends StatelessWidget {
  const _GoalLine({required this.bottom});
  final double bottom;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: bottom,
    child: const IgnorePointer(
      child: CustomPaint(size: Size(double.infinity, 1), painter: _DashPainter()),
    ),
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NqColors.textTertiary
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + 3.5, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}

class _StackedBar extends StatelessWidget {
  const _StackedBar({required this.summary, required this.height});
  final DaySummary summary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = summary.totals;
    final p = t.protein * 4;
    final c = t.carbs * 4;
    final f = t.fat * 9;
    final sum = p + c + f;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: 22,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: NqColors.track, borderRadius: BorderRadius.circular(7)),
      child: summary.mealCount == 0 || sum <= 0
          ? (summary.mealCount == 0 ? null : const ColoredBox(color: NqColors.inkSoft))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top to bottom: fat, carbs, protein.
                Expanded(
                  flex: math.max(1, (f / sum * 100).round()),
                  child: const ColoredBox(color: NqColors.fat),
                ),
                Expanded(
                  flex: math.max(1, (c / sum * 100).round()),
                  child: const ColoredBox(color: NqColors.carbs),
                ),
                Expanded(
                  flex: math.max(1, (p / sum * 100).round()),
                  child: const ColoredBox(color: NqColors.protein),
                ),
              ],
            ),
    );
  }
}
