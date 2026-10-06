import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/format.dart';
import '../../app/theme.dart';
import '../../domain/models/user_profile.dart';
import '../../services/coach/coach_service.dart' show DaySummary;

/// Seven daily calorie bars against the goal band. Tap a bar to open that day.
class WeekChart extends StatelessWidget {
  const WeekChart({
    super.key,
    required this.days,
    required this.range,
    required this.selected,
    required this.onSelect,
  });

  final List<DaySummary> days;
  final CalorieRange? range;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  static const _chartHeight = 140.0;

  @override
  Widget build(BuildContext context) {
    final maxKcal = days.map((d) => d.totals.calories).fold<double>(0, math.max);
    final scaleMax = math.max(1500.0, math.max(maxKcal, (range?.max ?? 0).toDouble()) * 1.15);
    double h(num kcal) => _chartHeight * (kcal / scaleMax).clamp(0.0, 1.0);

    return Column(
      children: [
        SizedBox(
          height: _chartHeight,
          child: Stack(
            children: [
              if (range != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: h(range!.min),
                  height: math.max(2, h(range!.max) - h(range!.min)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: NqColors.sage.withValues(alpha: 0.10),
                      border: Border.symmetric(
                        horizontal: BorderSide(color: NqColors.sage.withValues(alpha: 0.35), width: 0.6),
                      ),
                    ),
                  ),
                ),
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
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onSelect(d.day);
                          },
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              width: 20,
                              height: d.mealCount == 0 ? 3 : math.max(6, h(d.totals.calories)),
                              decoration: BoxDecoration(
                                color: _barColor(d),
                                borderRadius: BorderRadius.circular(6),
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
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(d.day),
                  child: Column(
                    children: [
                      Text(weekdayInitial(d.day), style: NqText.caption),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: d.day == selected ? NqColors.textPrimary : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${d.day.day}',
                          style: NqText.numberSmall.copyWith(
                            fontSize: 14,
                            color: d.day == selected ? NqColors.background : NqColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _barColor(DaySummary d) {
    final selectedDay = d.day == selected;
    if (d.mealCount == 0) return NqColors.raisedHigh;
    final r = range;
    final base = r != null && d.totals.calories > r.max
        ? NqColors.amber
        : (r == null ? NqColors.textSecondary : NqColors.sage);
    return selectedDay ? base : base.withValues(alpha: 0.45);
  }
}
