import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_scope.dart';
import '../../app/format.dart';
import '../../app/theme.dart';
import '../../domain/models/meal.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/buttons.dart';
import '../../widgets/calorie_gauge.dart';
import '../../widgets/labels.dart';
import '../../widgets/macro_summary.dart';
import '../../widgets/meal_row.dart';
import '../../widgets/surfaces.dart';
import '../meal_editor/meal_editor_screen.dart';
import '../scan/scan_screen.dart';
import '../settings/goal_sheets.dart';
import '../shell/home_shell.dart';

/// The daily dashboard: calories against the goal range, macros, the main
/// "Scan meal" action, a coach nudge, and today's meals.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  static Future<void> openScan(BuildContext context) async {
    final result = await Navigator.of(context)
        .push<EditorResult>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ScanScreen()));
    if (result != null && context.mounted) showToast(context, result.message);
  }

  static Future<void> openManual(BuildContext context, {DateTime? at}) async {
    final result = await Navigator.of(context).push<EditorResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MealEditorScreen(openAddFood: true, initialLoggedAt: at),
      ),
    );
    if (result != null && context.mounted) showToast(context, result.message);
  }

  static Future<void> openMeal(BuildContext context, Meal meal) async {
    final result = await Navigator.of(context)
        .push<EditorResult>(MaterialPageRoute(builder: (_) => MealEditorScreen.edit(meal)));
    if (result != null && context.mounted) showToast(context, result.message);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.profile, scope.log]),
      builder: (context, _) {
        final log = scope.log;
        final profile = scope.profile.profile;
        final today = log.today();
        final meals = log.mealsForDay(today).reversed.toList();
        final totals = log.totalsForDay(today);
        final range = profile?.isMinor ?? false ? null : profile?.calorieGoal;
        // Minors never see targets; adults with a health consideration only see ones they entered.
        final protein = (profile?.isMinor ?? false) ? null : profile?.proteinTargetG;
        final insight = scope.coach.service.insight(scope.coach.currentContext());
        final padding = MediaQuery.paddingOf(context);

        return ListView(
          padding: EdgeInsets.fromLTRB(
            NqSpace.page,
            padding.top + NqSpace.md,
            NqSpace.page,
            padding.bottom + 32,
          ),
          children: [
            Text(longDate(today), style: NqText.callout.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            const Text('Today', style: NqText.largeTitle),
            const SizedBox(height: NqSpace.lg),
            Center(
              child: CalorieGauge(calories: totals.calories, range: range),
            ),
            Transform.translate(
              offset: const Offset(0, -18),
              child: Column(
                children: [
                  Text(
                    gaugeStatus(totals.calories, range),
                    style: NqText.subhead.copyWith(color: NqColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  if (range == null && !(profile?.isMinor ?? false))
                    QuietButton(label: 'Set a goal', onPressed: () => showCalorieGoalSheet(context)),
                ],
              ),
            ),
            NqCard(
              child: MacroSummary(totals: totals, proteinTarget: protein),
            ),
            const SizedBox(height: NqSpace.lg),
            PrimaryButton(
              label: 'Scan meal',
              icon: Icons.photo_camera_rounded,
              onPressed: () => openScan(context),
            ),
            Center(
              child: QuietButton(
                label: 'Add a meal manually',
                icon: Icons.edit_note_rounded,
                color: NqColors.textSecondary,
                onPressed: () => openManual(context),
              ),
            ),
            const SizedBox(height: NqSpace.sm),
            _CoachCard(
              text: insight.text,
              isDemo: scope.coach.service.isDemo,
              onTap: () => HomeShellScope.maybeOf(context)?.openCoach(insight.suggestedPrompt),
            ),
            SectionHeader(
              'Meals',
              trailing: meals.isEmpty ? null : Text('${meals.length} logged', style: NqText.footnote),
            ),
            if (meals.isEmpty)
              NqCard(
                child: Column(
                  children: [
                    const Icon(Icons.restaurant_rounded, color: NqColors.textTertiary, size: 28),
                    const SizedBox(height: NqSpace.sm),
                    const Text('No meals yet today', style: NqText.headline),
                    const SizedBox(height: 4),
                    Text(
                      'Scan your first meal, or add one by hand.',
                      style: NqText.footnote,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              NqGroup(
                children: [for (final m in meals) MealRow(meal: m, onTap: () => openMeal(context, m))],
              ),
            const SizedBox(height: NqSpace.xl),
            Text(AppConfig.estimateDisclaimer, style: NqText.caption, textAlign: TextAlign.center),
          ],
        );
      },
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.text, required this.isDemo, required this.onTap});

  final String text;
  final bool isDemo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NqCard(
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: NqColors.sage.withValues(alpha: 0.14), shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome_outlined, color: NqColors.sage, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Coach', style: NqText.footnote.copyWith(fontWeight: FontWeight.w600)),
                  if (isDemo) ...[const SizedBox(width: 6), const DemoBadge()],
                ],
              ),
              const SizedBox(height: 3),
              Text(text, style: NqText.subhead.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded, color: NqColors.textTertiary),
      ],
    ),
  );
}
