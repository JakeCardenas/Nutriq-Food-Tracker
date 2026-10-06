import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_scope.dart';
import '../../app/format.dart';
import '../../app/theme.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/units.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/controls.dart';
import '../../widgets/nutriq_mark.dart';
import '../../widgets/surfaces.dart';
import '../meal_editor/food_item_form.dart' show SheetBody;
import 'data_screens.dart';
import 'goal_sheets.dart';
import 'profile_screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.profile, scope.log]),
      builder: (context, _) {
        final profile = scope.profile.profile;
        final settings = scope.profile.settings;
        final padding = MediaQuery.paddingOf(context);
        return ListView(
          padding: EdgeInsets.fromLTRB(
            NqSpace.page,
            padding.top + NqSpace.md,
            NqSpace.page,
            padding.bottom + 40,
          ),
          children: [
            const Text('Settings', style: NqText.largeTitle),
            const SizedBox(height: NqSpace.lg),
            NqCard(
              onTap: () => _push(context, const ProfileEditScreen()),
              child: Row(
                children: [
                  const NutriqMark(size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.goal?.title ?? (profile == null ? 'No profile' : 'No goal chosen'),
                          style: NqText.headline,
                        ),
                        const SizedBox(height: 2),
                        Text(_profileSummary(profile, settings.units), style: NqText.footnote),
                      ],
                    ),
                  ),
                  Text('Edit', style: NqText.subhead.copyWith(color: NqColors.sage)),
                ],
              ),
            ),
            NqGroup(
              header: 'Goals',
              footer: 'Goals are estimates you can change any time — not medical advice.',
              children: [
                NqRow(
                  icon: Icons.donut_large_rounded,
                  title: 'Calorie goal',
                  value: profile?.isMinor ?? false
                      ? 'Not offered'
                      : profile?.calorieGoal == null
                      ? 'Not set'
                      : '${fmtKcal(profile!.calorieGoal!.min)}–${fmtKcal(profile.calorieGoal!.max)}',
                  onTap: () => showCalorieGoalSheet(context),
                ),
                if (!(profile?.isMinor ?? false))
                  NqRow(
                    icon: Icons.egg_alt_outlined,
                    title: 'Protein reference',
                    value: profile?.proteinTargetG == null ? 'Not set' : '${profile!.proteinTargetG} g',
                    onTap: () => showProteinSheet(context),
                  ),
                if (!(profile?.dietingGuidanceRestricted ?? false))
                  NqRow(
                    icon: Icons.calculate_outlined,
                    title: 'Recalculate starting point',
                    onTap: () => _push(context, const StartingPointScreen()),
                  ),
              ],
            ),
            NqGroup(
              header: 'Preferences',
              children: [
                NqRow(
                  icon: Icons.straighten_rounded,
                  title: 'Units',
                  value: settings.units == UnitSystem.metric ? 'Metric (cm, kg)' : 'Imperial (ft, lb)',
                  onTap: () => scope.profile.updateSettings(
                    settings.copyWith(
                      units: settings.units == UnitSystem.metric ? UnitSystem.imperial : UnitSystem.metric,
                    ),
                  ),
                  showChevron: false,
                  trailing: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.swap_horiz_rounded, color: NqColors.textTertiary, size: 20),
                  ),
                ),
                NqRow(
                  icon: Icons.bedtime_outlined,
                  title: 'Day starts at',
                  value: _hourLabel(settings.dayStartHour),
                  onTap: () => _dayStartSheet(context, settings),
                ),
              ],
            ),
            NqGroup(
              header: 'Logging',
              children: [
                NqRow(
                  icon: Icons.bookmark_border_rounded,
                  title: 'My foods',
                  value: '${scope.log.savedFoods.length}',
                  onTap: () => _push(context, const SavedFoodsScreen()),
                ),
                NqRow(
                  icon: Icons.thumbs_up_down_outlined,
                  title: 'Scan feedback',
                  subtitle: 'Too high, about right, or too low?',
                  onTap: () => _push(context, const ScanFeedbackScreen()),
                ),
              ],
            ),
            NqGroup(
              header: 'Privacy & data',
              footer: 'Everything stays on this phone: no account, no analytics, no uploads.',
              children: [
                NqRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'What Nutriq stores',
                  onTap: () => showInfoDialog(
                    context,
                    title: 'What Nutriq stores',
                    message:
                        'On this phone only: your optional profile and goals, meals and their photos, '
                        'saved foods, and scan feedback. Coach chats aren’t saved. Nothing is sent anywhere in '
                        'this version — demo analysis and the demo coach run on the device.',
                  ),
                ),
                NqRow(
                  icon: Icons.person_remove_outlined,
                  title: 'Delete profile',
                  subtitle: 'Keeps your meals',
                  destructive: true,
                  onTap: profile == null
                      ? null
                      : () async {
                          final ok = await confirmAction(
                            context,
                            title: 'Delete your profile?',
                            message:
                                'Your age, body measurements, goal and targets will be removed. '
                                'Meals stay in your log.',
                            confirmLabel: 'Delete profile',
                          );
                          if (ok) await scope.profile.clearProfile();
                        },
                ),
                NqRow(
                  icon: Icons.no_meals_outlined,
                  title: 'Delete all meals',
                  destructive: true,
                  onTap: scope.log.meals.isEmpty
                      ? null
                      : () async {
                          final ok = await confirmAction(
                            context,
                            title: 'Delete all meals?',
                            message: 'Every logged meal and its photo will be permanently removed from this phone.',
                            confirmLabel: 'Delete meals',
                          );
                          if (ok) await scope.log.deleteAllMeals();
                        },
                ),
                NqRow(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete all data',
                  subtitle: 'Start over from the welcome screen',
                  destructive: true,
                  onTap: () async {
                    final ok = await confirmAction(
                      context,
                      title: 'Delete all data?',
                      message:
                          'Your profile, meals, photos, saved foods and feedback will be permanently '
                          'removed from this phone.',
                      confirmLabel: 'Delete everything',
                    );
                    if (!ok || !context.mounted) return;
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    await scope.log.deleteAllMeals();
                    scope.coach.clear();
                    await scope.profile.resetAll();
                    await scope.log.reload();
                  },
                ),
              ],
            ),
            NqGroup(
              header: 'About',
              footer:
                  '${AppConfig.estimateDisclaimer} ${AppConfig.appName} doesn’t diagnose or treat any '
                  'condition. For medical or dietary advice, talk to a qualified professional.',
              children: [
                NqRow(
                  title: 'Food analysis',
                  value: scope.analysis.isDemo ? 'Demo · sample results' : 'Connected',
                ),
                NqRow(title: 'Coach', value: scope.coach.service.isDemo ? 'Demo · scripted' : 'Connected'),
                const NqRow(title: 'Version', value: AppConfig.version),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _profileSummary(UserProfile? p, UnitSystem units) {
    if (p == null) return 'Add details for a personal starting point';
    final parts = [
      if (p.age != null) '${p.age} y',
      if (p.heightCm != null) formatHeight(p.heightCm!, units),
      if (p.weightKg != null) formatWeight(p.weightKg!, units),
      if (p.activity != null) p.activity!.title,
    ];
    return parts.isEmpty ? 'Tap to add details' : parts.join(' · ');
  }

  static String _hourLabel(int h) => h == 0 ? 'Midnight' : '$h AM';

  void _dayStartSheet(BuildContext context, AppSettings settings) {
    final controller = AppScope.of(context).profile;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SheetBody(
        title: 'Day starts at',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'For late nights and night shifts: meals logged before this time count toward the previous day.',
              style: NqText.callout,
            ),
            const SizedBox(height: NqSpace.lg),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => ChoiceChips<int>(
                options: const [0, 2, 3, 4, 5, 6],
                selected: controller.settings.dayStartHour,
                labelOf: _hourLabel,
                onSelected: (h) => controller.updateSettings(controller.settings.copyWith(dayStartHour: h)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
