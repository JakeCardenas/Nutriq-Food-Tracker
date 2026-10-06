import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/format.dart';
import '../../app/theme.dart';
import '../../domain/streak.dart';
import '../../widgets/buttons.dart';
import '../../widgets/labels.dart';
import '../../widgets/meal_cards.dart';
import '../../widgets/surfaces.dart';
import '../scan/meal_flows.dart';
import '../shell/home_shell.dart';
import 'week_chart.dart';

/// Streak, weekly average, a week of calories split by macro, and any day's meals.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime? _windowEnd;
  DateTime? _selected;

  void _shiftWeek(int direction, DateTime today) {
    final end = _windowEnd ?? today;
    var next = DateTime(end.year, end.month, end.day + 7 * direction);
    if (next.isAfter(today)) next = today;
    setState(() {
      _windowEnd = next;
      _selected = next;
    });
  }

  Future<void> _jump(DateTime today) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected ?? today,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked == null) return;
    final plus3 = DateTime(picked.year, picked.month, picked.day + 3);
    setState(() {
      _windowEnd = plus3.isAfter(today) ? today : plus3;
      _selected = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.log, scope.profile]),
      builder: (context, _) {
        final log = scope.log;
        final today = log.today();
        final end = _windowEnd ?? today;
        final selected = _selected ?? today;
        final days = log.summariesEnding(end);
        final profile = scope.profile.profile;
        final range = (profile?.isMinor ?? false) ? null : profile?.calorieGoal;
        final meals = log.mealsForDay(selected).reversed.toList();
        final totals = log.totalsForDay(selected);
        final logged = days.where((d) => d.mealCount > 0).toList();
        final avg = logged.isEmpty
            ? null
            : logged.map((d) => d.totals.calories).reduce((a, b) => a + b) / logged.length;
        final loggedDays = log.meals.map(log.dayOf).toSet();
        final streak = loggingStreak(loggedDays, today);
        final lastSeven = log.summariesEnding(today);
        final padding = MediaQuery.paddingOf(context);

        return ListView(
          padding: EdgeInsets.fromLTRB(NqSpace.page, padding.top + 8, NqSpace.page, HomeShell.bottomInset(context)),
          children: [
            Row(
              children: [
                const Expanded(child: Text('History', style: NqText.largeTitle)),
                IconButton(
                  tooltip: 'Jump to date',
                  icon: const Icon(Icons.calendar_today_outlined, color: NqColors.ink),
                  onPressed: () => _jump(today),
                ),
              ],
            ),
            const SizedBox(height: NqSpace.md),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: NqCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 34,
                            color: streak > 0 ? NqColors.flame : NqColors.textTertiary,
                          ),
                          const SizedBox(height: 6),
                          Text('$streak', style: NqText.heroNumber.copyWith(fontSize: 34)),
                          Text('day streak', style: NqText.footnote),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final d in lastSeven)
                                Column(
                                  children: [
                                    Text(weekdayInitial(d.day), style: NqText.caption.copyWith(fontSize: 10)),
                                    const SizedBox(height: 3),
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: d.mealCount > 0 ? NqColors.flame : NqColors.track,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: NqCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.insights_rounded, size: 30, color: NqColors.ink),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              avg == null ? '—' : fmtKcal(avg),
                              style: NqText.heroNumber.copyWith(fontSize: 34),
                            ),
                          ),
                          Text('avg kcal · est.', style: NqText.footnote),
                          const Spacer(),
                          Text(
                            logged.isEmpty
                                ? 'Nothing logged this week'
                                : 'Across ${logged.length} logged ${logged.length == 1 ? 'day' : 'days'} this week',
                            style: NqText.caption,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NqSpace.md),
            NqCard(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Calories', style: NqText.headline),
                            Text('${shortDate(days.first.day)} – ${shortDate(days.last.day)}', style: NqText.footnote),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Previous week',
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () => _shiftWeek(-1, today),
                      ),
                      IconButton(
                        tooltip: 'Next week',
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: end == today ? null : () => _shiftWeek(1, today),
                      ),
                    ],
                  ),
                  const SizedBox(height: NqSpace.md),
                  WeekChart(
                    days: days,
                    range: range,
                    selected: selected,
                    onSelect: (d) => setState(() => _selected = d),
                  ),
                  const SizedBox(height: NqSpace.md),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      const LegendDot(color: NqColors.protein, label: 'Protein'),
                      const LegendDot(color: NqColors.carbs, label: 'Carbs'),
                      const LegendDot(color: NqColors.fat, label: 'Fats'),
                      if (range != null) const LegendDot(color: NqColors.textTertiary, label: 'Goal range (dashed)'),
                    ],
                  ),
                ],
              ),
            ),
            SectionHeader(
              dayLabel(selected, today),
              trailing: meals.isEmpty ? null : Text('≈ ${fmtKcal(totals.calories)} kcal', style: NqText.numberSmall),
            ),
            if (meals.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: NqSpace.md),
                child: Wrap(
                  spacing: 14,
                  children: [
                    MacroValue(macro: Macro.protein, text: 'Protein ${fmtGrams(totals.protein)}'),
                    MacroValue(macro: Macro.carbs, text: 'Carbs ${fmtGrams(totals.carbs)}'),
                    MacroValue(macro: Macro.fat, text: 'Fats ${fmtGrams(totals.fat)}'),
                  ],
                ),
              ),
            if (meals.isEmpty)
              NqCard(
                child: Column(
                  children: [
                    const Text('Nothing logged', style: NqText.headline),
                    const SizedBox(height: 4),
                    Text('Forgot a meal? You can add it to this day.', style: NqText.footnote),
                    const SizedBox(height: NqSpace.md),
                    SecondaryButton(
                      label: 'Add a meal to this day',
                      icon: Icons.add_rounded,
                      height: 46,
                      onPressed: () => MealFlows.openManual(
                        context,
                        at: selected == today ? null : DateTime(selected.year, selected.month, selected.day, 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final m in meals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MealCard(meal: m, onTap: () => MealFlows.openMeal(context, m)),
                ),
            if (log.dayStartHour > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, NqSpace.md, 4, 0),
                child: Text('Days start at ${log.dayStartHour} AM (Settings → Day starts at).', style: NqText.caption),
              ),
          ],
        );
      },
    );
  }
}
