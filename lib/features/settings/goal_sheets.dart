import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/format.dart';
import '../../app/theme.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/starting_point.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/labels.dart';
import '../meal_editor/food_item_form.dart' show SheetBody;

/// Edit or remove the daily calorie range.
Future<void> showCalorieGoalSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _CalorieGoalSheet(),
  );
}

class _CalorieGoalSheet extends StatefulWidget {
  const _CalorieGoalSheet();

  @override
  State<_CalorieGoalSheet> createState() => _CalorieGoalSheetState();
}

class _CalorieGoalSheetState extends State<_CalorieGoalSheet> {
  late final UserProfile _profile = AppScope.of(context).profile.profile ?? const UserProfile();
  late final CalorieRange _suggested =
      StartingPoint.calculate(_profile).range ?? const CalorieRange(min: 1900, max: 2200);
  late int _min = _profile.calorieGoal?.min ?? _suggested.min;
  late int _max = _profile.calorieGoal?.max ?? _suggested.max;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).profile;
    if (_profile.isMinor) {
      return SheetBody(
        title: 'Calorie goal',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NoticeCard(
              icon: Icons.favorite_border_rounded,
              color: NqColors.sage,
              title: 'Not offered under 18',
              message:
                  'Nutriq doesn’t set calorie targets for people under 18. You can still log meals and see '
                  'your totals. A doctor or registered dietitian can help with personal questions.',
            ),
            const SizedBox(height: NqSpace.lg),
            SecondaryButton(label: 'OK', onPressed: () => Navigator.pop(context)),
          ],
        ),
      );
    }
    return SheetBody(
      title: 'Calorie goal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _profile.hasHealthConsideration
                ? 'Enter the range your doctor or dietitian suggested. Nutriq won’t calculate one for you.'
                : 'A range, not a single number — real intake varies day to day. All values are estimates.',
            style: NqText.callout,
          ),
          const SizedBox(height: NqSpace.lg),
          Text('${fmtKcal(_min)} – ${fmtKcal(_max)} kcal/day', style: NqText.metric),
          const SizedBox(height: NqSpace.md),
          _row('Low end', _min, (v) => setState(() => _min = v), 1200, _max - 50),
          const SizedBox(height: NqSpace.sm),
          _row('High end', _max, (v) => setState(() => _max = v), _min + 50, 6000),
          const SizedBox(height: NqSpace.xl),
          PrimaryButton(
            label: 'Save range',
            height: 52,
            onPressed: () async {
              await controller.setCalorieGoal(
                CalorieRange(
                  min: _min,
                  max: _max,
                  custom: _min != _suggested.min || _max != _suggested.max || _profile.hasHealthConsideration,
                ),
              );
              if (context.mounted) Navigator.pop(context);
            },
          ),
          if (_profile.calorieGoal != null)
            Center(
              child: QuietButton(
                label: 'Remove calorie goal',
                color: NqColors.coral,
                onPressed: () async {
                  await controller.setCalorieGoal(null);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, int value, ValueChanged<int> onChanged, int lower, int upper) => Row(
    children: [
      Expanded(child: Text(label, style: NqText.body)),
      StepperControl(
        value: value.toDouble(),
        step: 50,
        min: lower.toDouble(),
        max: upper.toDouble(),
        semanticLabel: label,
        format: fmtKcal,
        onChanged: (v) => onChanged(v.round()),
      ),
    ],
  );
}

/// Edit or remove the protein reference.
Future<void> showProteinSheet(BuildContext context) {
  final controller = AppScope.of(context).profile;
  final profile = controller.profile ?? const UserProfile();
  var grams = profile.proteinTargetG ?? StartingPoint.calculate(profile).proteinReferenceG ?? 100;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SheetBody(
        title: 'Protein reference',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'A daily reference for protein, shown on Today. Many sports-nutrition guidelines use about '
              '1.2–1.6 g per kg of body weight. It’s a reference, not a requirement.',
              style: NqText.callout,
            ),
            const SizedBox(height: NqSpace.lg),
            Row(
              children: [
                const Expanded(child: Text('Grams per day', style: NqText.body)),
                StepperControl(
                  value: grams.toDouble(),
                  step: 5,
                  min: 30,
                  max: 300,
                  semanticLabel: 'Protein grams per day',
                  format: (v) => '${v.round()} g',
                  onChanged: (v) => setState(() => grams = v.round()),
                ),
              ],
            ),
            const SizedBox(height: NqSpace.xl),
            PrimaryButton(
              label: 'Save',
              height: 52,
              onPressed: () async {
                await controller.setProteinTarget(grams);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            if (profile.proteinTargetG != null)
              Center(
                child: QuietButton(
                  label: 'Remove protein reference',
                  color: NqColors.coral,
                  onPressed: () async {
                    await controller.setProteinTarget(null);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
