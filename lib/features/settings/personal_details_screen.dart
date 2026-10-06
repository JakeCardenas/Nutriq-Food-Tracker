import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/units.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/buttons.dart';
import '../../widgets/sheet.dart';
import '../../widgets/surfaces.dart';
import '../profile/profile_editors.dart';
import '../starting_point/starting_plan_view.dart';

/// Every onboarding answer, editable one at a time. Changes that trigger a
/// safeguard (under 18, pregnancy, breastfeeding, a medical condition) remove
/// calculated targets, and the person is told why.
class PersonalDetailsScreen extends StatelessWidget {
  const PersonalDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Personal details')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final p = controller.profile ?? const UserProfile();
          final units = controller.settings.units;
          return ListView(
            padding: const EdgeInsets.fromLTRB(NqSpace.page, 0, NqSpace.page, NqSpace.xxxl),
            children: [
              NqGroup(
                header: 'Your goal',
                children: [
                  NqRow(
                    icon: p.goal == null ? Icons.flag_outlined : goalIcon(p.goal!),
                    title: 'Goal',
                    value: p.goal?.title ?? 'Not set',
                    onTap: () => _edit<FitnessGoal?>(
                      context,
                      title: 'Your goal',
                      initial: p.goal,
                      saveOnSelect: true,
                      editor: (value, set) => GoalChoice(selected: value, onChanged: set),
                      apply: (v) => p.copyWith(goal: v),
                    ),
                  ),
                ],
              ),
              NqGroup(
                header: 'About you',
                footer: 'Used only to estimate a starting point. Every field is optional.',
                children: [
                  NqRow(
                    icon: Icons.cake_outlined,
                    title: 'Age',
                    value: p.age == null ? 'Not set' : '${p.age}',
                    onTap: () => _edit<int>(
                      context,
                      title: 'Age',
                      initial: p.age ?? 30,
                      canRemove: p.age != null,
                      editor: (value, set) => AgeWheel(age: value, onChanged: set),
                      apply: (v) => p.copyWith(age: v),
                      remove: () => p.copyWith(age: null),
                    ),
                  ),
                  NqRow(
                    icon: Icons.person_outline_rounded,
                    title: 'Sex for the estimate',
                    value: p.sex?.label ?? 'Not set',
                    onTap: () => _edit<SexAnswer?>(
                      context,
                      title: 'Sex for the estimate',
                      note: 'Only used for one constant in the formula. “Prefer not to say” uses the midpoint.',
                      initial: sexAnswerOf(p, answered: true),
                      saveOnSelect: true,
                      editor: (value, set) => SexChoice(selected: value, onChanged: set),
                      apply: (v) => p.copyWith(sex: sexFromAnswer(v)),
                    ),
                  ),
                  NqRow(
                    icon: Icons.straighten_rounded,
                    title: 'Height & weight',
                    value: p.heightCm == null && p.weightKg == null
                        ? 'Not set'
                        : [
                            if (p.heightCm != null) formatHeight(p.heightCm!, units),
                            if (p.weightKg != null) formatWeight(p.weightKg!, units),
                          ].join(' · '),
                    onTap: () => _editBody(context, p, units),
                  ),
                  NqRow(
                    icon: Icons.flag_circle_outlined,
                    title: 'Goal weight',
                    value: p.goalWeightKg == null ? 'Not set' : formatWeight(p.goalWeightKg!, units),
                    onTap: () => _edit<double>(
                      context,
                      title: 'Goal weight',
                      note: 'Optional. Nutriq never suggests a timeline or a rate of loss.',
                      initial: p.goalWeightKg ?? p.weightKg ?? 70,
                      canRemove: p.goalWeightKg != null,
                      editor: (value, set) => ListenableBuilder(
                        listenable: controller,
                        builder: (context, _) => Center(
                          child: WeightWithUnits(
                            units: controller.settings.units,
                            kg: value,
                            onChanged: set,
                            onUnits: (u) => controller.updateSettings(controller.settings.copyWith(units: u)),
                          ),
                        ),
                      ),
                      apply: (v) => p.copyWith(goalWeightKg: v),
                      remove: () => p.copyWith(goalWeightKg: null),
                    ),
                  ),
                ],
              ),
              NqGroup(
                header: 'Activity',
                children: [
                  NqRow(
                    icon: Icons.directions_walk_rounded,
                    title: 'Daily activity',
                    value: p.activity?.title ?? 'Not set',
                    onTap: () => _edit<ActivityLevel?>(
                      context,
                      title: 'Daily activity',
                      initial: p.activity,
                      saveOnSelect: true,
                      editor: (value, set) => ActivityChoice(selected: value, onChanged: set),
                      apply: (v) => p.copyWith(activity: v),
                    ),
                  ),
                  NqRow(
                    icon: Icons.fitness_center_rounded,
                    title: 'Workouts per week',
                    value: p.workoutDaysPerWeek == null ? 'Not set' : '${p.workoutDaysPerWeek}',
                    onTap: () => _edit<int>(
                      context,
                      title: 'Workouts per week',
                      initial: p.workoutDaysPerWeek ?? 3,
                      canRemove: p.workoutDaysPerWeek != null,
                      editor: (value, set) => WorkoutsWheel(days: value, onChanged: set),
                      apply: (v) => p.copyWith(workoutDaysPerWeek: v),
                      remove: () => p.copyWith(workoutDaysPerWeek: null),
                    ),
                  ),
                ],
              ),
              NqGroup(
                header: 'Health check',
                footer: 'If any of these apply, Nutriq won’t calculate calorie targets for you.',
                children: [
                  NqRow(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Health considerations',
                    value: p.health.isEmpty ? 'None' : p.health.map((h) => h.label.split(' ').first).join(', '),
                    onTap: () => _editHealth(context, p),
                  ),
                ],
              ),
              const SizedBox(height: NqSpace.xl),
              if (!p.dietingGuidanceRestricted)
                SecondaryButton(
                  label: 'Recalculate starting plan',
                  icon: Icons.calculate_outlined,
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StartingPlanScreen())),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editBody(BuildContext context, UserProfile p, UnitSystem units) {
    final controller = AppScope.of(context).profile;
    var height = p.heightCm ?? 170;
    var weight = p.weightKg ?? 70;
    return showNqSheet<void>(
      context,
      title: 'Height & weight',
      child: StatefulBuilder(
        builder: (sheetContext, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => BodyWheels(
                units: controller.settings.units,
                heightCm: height,
                weightKg: weight,
                onHeight: (v) => setState(() => height = v),
                onWeight: (v) => setState(() => weight = v),
                onUnits: (u) => controller.updateSettings(controller.settings.copyWith(units: u)),
              ),
            ),
            const SizedBox(height: NqSpace.xl),
            PrimaryButton(
              label: 'Save',
              onPressed: () async {
                Navigator.pop(sheetContext);
                await saveProfileWithSafeguards(context, p.copyWith(heightCm: height, weightKg: weight));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editHealth(BuildContext context, UserProfile p) {
    var selected = {...p.health};
    var noneChosen = p.health.isEmpty;
    return showNqSheet<void>(
      context,
      title: 'Health check',
      child: StatefulBuilder(
        builder: (sheetContext, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Do any of these apply to you right now?', style: NqText.callout),
            const SizedBox(height: NqSpace.lg),
            HealthChoice(
              selected: selected,
              noneChosen: noneChosen,
              onChanged: (s, {required bool none}) => setState(() {
                selected = s;
                noneChosen = none;
              }),
            ),
            const SizedBox(height: NqSpace.xl),
            PrimaryButton(
              label: 'Save',
              onPressed: () async {
                Navigator.pop(sheetContext);
                await saveProfileWithSafeguards(context, p.copyWith(health: selected));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// One-field editor sheet. [saveOnSelect] saves as soon as an option is tapped.
  Future<void> _edit<T>(
    BuildContext context, {
    required String title,
    required T initial,
    required Widget Function(T value, ValueChanged<T> set) editor,
    required UserProfile Function(T value) apply,
    String? note,
    bool saveOnSelect = false,
    bool canRemove = false,
    UserProfile Function()? remove,
  }) {
    var value = initial;
    return showNqSheet<void>(
      context,
      title: title,
      child: StatefulBuilder(
        builder: (sheetContext, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (note != null) ...[Text(note, style: NqText.callout), const SizedBox(height: NqSpace.lg)],
            editor(value, (v) async {
              setState(() => value = v);
              if (saveOnSelect) {
                Navigator.pop(sheetContext);
                await saveProfileWithSafeguards(context, apply(v));
              }
            }),
            if (!saveOnSelect) ...[
              const SizedBox(height: NqSpace.xl),
              PrimaryButton(
                label: 'Save',
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await saveProfileWithSafeguards(context, apply(value));
                },
              ),
            ],
            if (canRemove && remove != null)
              Center(
                child: QuietButton(
                  label: 'Clear',
                  color: NqColors.textSecondary,
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await saveProfileWithSafeguards(context, remove());
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Saves [profile], first removing targets a safeguard no longer allows:
/// none for under-18s; no calculated calorie goal with a health consideration
/// (a range the person entered themselves is kept).
Future<void> saveProfileWithSafeguards(BuildContext context, UserProfile profile) async {
  final controller = AppScope.of(context).profile;
  var p = profile;
  String? notice;
  if (p.isMinor && (p.calorieGoal != null || p.proteinTargetG != null)) {
    p = p.copyWith(calorieGoal: null, proteinTargetG: null);
    notice = 'Calorie and protein targets were removed — Nutriq doesn’t set targets for people under 18.';
  } else if (p.hasHealthConsideration && p.calorieGoal != null && !p.calorieGoal!.custom) {
    p = p.copyWith(calorieGoal: null);
    notice = 'Your calculated calorie goal was removed. You can enter a range from your doctor or dietitian.';
  }
  await controller.saveProfile(p);
  if (notice != null && context.mounted) showToast(context, notice);
}

/// Recalculates the starting plan from the saved profile.
class StartingPlanScreen extends StatefulWidget {
  const StartingPlanScreen({super.key});

  @override
  State<StartingPlanScreen> createState() => _StartingPlanScreenState();
}

class _StartingPlanScreenState extends State<StartingPlanScreen> {
  PlanChoice _plan = const PlanChoice();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).profile;
    final profile = controller.profile ?? const UserProfile();
    return Scaffold(
      appBar: AppBar(title: const Text('Starting plan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(NqSpace.page, 0, NqSpace.page, NqSpace.xxxl),
        children: [StartingPlanView(profile: profile, onChanged: (p) => _plan = p)],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(NqSpace.page, 8, NqSpace.page, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrimaryButton(
                label: 'Use this plan',
                onPressed: () async {
                  if (_plan.range == null) {
                    Navigator.pop(context);
                    return;
                  }
                  await controller.saveProfile(
                    profile.copyWith(calorieGoal: _plan.range, proteinTargetG: _plan.proteinG),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    showToast(context, 'Plan updated');
                  }
                },
              ),
              QuietButton(
                label: profile.calorieGoal == null ? 'Not now' : 'Keep my current goal',
                color: NqColors.textSecondary,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
