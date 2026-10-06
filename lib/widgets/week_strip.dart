import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/format.dart';
import '../app/theme.dart';
import '../domain/models/user_profile.dart';
import '../services/coach/coach_service.dart' show DaySummary;
import 'dashed_circle.dart';

/// Seven days with a status ring each: dashed = nothing logged, green = within
/// the goal range, amber = above it, ink = logged (below the range, or no goal set).
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.today,
    required this.range,
    required this.onSelect,
  });

  final List<DaySummary> days;
  final DateTime selected;
  final DateTime today;
  final CalorieRange? range;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final d in days)
        Expanded(
          child: _Day(
            summary: d,
            selected: d.day == selected,
            future: d.day.isAfter(today),
            range: range,
            onTap: d.day.isAfter(today)
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onSelect(d.day);
                  },
          ),
        ),
    ],
  );
}

class _Day extends StatelessWidget {
  const _Day({
    required this.summary,
    required this.selected,
    required this.future,
    required this.range,
    required this.onTap,
  });

  final DaySummary summary;
  final bool selected;
  final bool future;
  final CalorieRange? range;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final logged = summary.mealCount > 0;
    final r = range;
    final kcal = summary.totals.calories;
    final ringColor = !logged
        ? null
        : r == null || kcal < r.min
        ? NqColors.ink
        : kcal > r.max
        ? NqColors.aboveRange
        : NqColors.inRange;
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '${longDate(summary.day)}${logged ? ', about ${fmtKcal(kcal)} calories' : ', nothing logged'}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? NqColors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected ? NqShadow.card : null,
          ),
          child: Column(
            children: [
              Text(
                weekdayShort(summary.day),
                style: NqText.caption.copyWith(color: selected ? NqColors.ink : NqColors.textSecondary),
              ),
              const SizedBox(height: 6),
              SizedBox.square(
                dimension: 34,
                child: ringColor == null
                    ? DashedCircle(
                        color: future ? NqColors.hairline : NqColors.textTertiary,
                        child: Text('${summary.day.day}', style: _num(future)),
                      )
                    : Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: ringColor, width: 2),
                        ),
                        child: Text('${summary.day.day}', style: _num(false)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _num(bool faded) =>
      NqText.numberSmall.copyWith(fontSize: 14, color: faded ? NqColors.textTertiary : NqColors.ink);
}
