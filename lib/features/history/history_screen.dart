import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/format.dart';
import '../../app/theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/labels.dart';
import '../../widgets/meal_row.dart';
import '../../widgets/surfaces.dart';
import '../today/today_screen.dart';
import 'week_chart.dart';

/// Browse saved meals by day; drill into any meal to edit, move or delete it.
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
        final meals = log.mealsForDay(selected);
        final totals = log.totalsForDay(selected);
        final logged = days.where((d) => d.mealCount > 0).toList();
        final avg = logged.isEmpty
            ? null
            : logged.map((d) => d.totals.calories).reduce((a, b) => a + b) / logged.length;
        final padding = MediaQuery.paddingOf(context);

        return ListView(
          padding: EdgeInsets.fromLTRB(
            NqSpace.page,
            padding.top + NqSpace.md,
            NqSpace.page,
            padding.bottom + 32,
          ),
          children: [
            Row(
              children: [
                const Expanded(child: Text('History', style: NqText.largeTitle)),
                IconButton(
                  tooltip: 'Jump to date',
                  icon: const Icon(Icons.calendar_today_outlined, color: NqColors.textSecondary),
                  onPressed: () => _jump(today),
                ),
              ],
            ),
            const SizedBox(height: NqSpace.md),
            NqCard(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous week',
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () => _shiftWeek(-1, today),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${shortDate(days.first.day)} – ${shortDate(days.last.day)}',
                              style: NqText.headline,
                            ),
                            Text(
                              avg == null
                                  ? 'Nothing logged this week'
                                  : 'Avg ≈ ${fmtKcal(avg)} kcal on ${logged.length} logged '
                                        '${logged.length == 1 ? 'day' : 'days'}',
                              style: NqText.footnote,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next week',
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: end == today ? null : () => _shiftWeek(1, today),
                      ),
                    ],
                  ),
                  const SizedBox(height: NqSpace.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: WeekChart(
                      days: days,
                      range: range,
                      selected: selected,
                      onSelect: (d) => setState(() => _selected = d),
                    ),
                  ),
                  if (range != null) ...[
                    const SizedBox(height: NqSpace.md),
                    LegendDot(
                      color: NqColors.sage.withValues(alpha: 0.5),
                      label: 'Shaded band = your goal range',
                    ),
                  ],
                ],
              ),
            ),
            SectionHeader(
              dayLabel(selected, today),
              trailing: meals.isEmpty
                  ? null
                  : Text('≈ ${fmtKcal(totals.calories)} kcal', style: NqText.numberSmall),
            ),
            if (meals.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: NqSpace.sm),
                child: Wrap(
                  spacing: 14,
                  children: [
                    LegendDot(color: NqColors.protein, label: 'P ${fmtGrams(totals.protein)}'),
                    LegendDot(color: NqColors.carbs, label: 'C ${fmtGrams(totals.carbs)}'),
                    LegendDot(color: NqColors.fat, label: 'F ${fmtGrams(totals.fat)}'),
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
                      height: 48,
                      onPressed: () => TodayScreen.openManual(
                        context,
                        at: selected == today
                            ? null
                            : DateTime(selected.year, selected.month, selected.day, 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              NqGroup(
                children: [
                  for (final m in meals) MealRow(meal: m, onTap: () => TodayScreen.openMeal(context, m)),
                ],
              ),
            if (log.dayStartHour > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, NqSpace.md, 16, 0),
                child: Text(
                  'Days start at ${log.dayStartHour} AM (Settings → Day starts at).',
                  style: NqText.caption,
                ),
              ),
          ],
        );
      },
    );
  }
}
