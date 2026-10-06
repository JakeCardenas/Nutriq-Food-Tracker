import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/units.dart';
import '../../widgets/controls.dart';

/// Profile inputs shared by onboarding steps and Settings → Personal details.
/// Every field is optional; each explains why it's asked.

IconData goalIcon(FitnessGoal g) => switch (g) {
  FitnessGoal.loseFat => Icons.trending_down_rounded,
  FitnessGoal.maintain => Icons.balance_rounded,
  FitnessGoal.gainMuscle => Icons.trending_up_rounded,
  FitnessGoal.buildStrength => Icons.fitness_center_rounded,
  FitnessGoal.generalFitness => Icons.directions_run_rounded,
  FitnessGoal.eatConsistently => Icons.event_repeat_rounded,
};

class GoalChoice extends StatelessWidget {
  const GoalChoice({super.key, required this.selected, required this.onChanged});

  final FitnessGoal? selected;
  final ValueChanged<FitnessGoal?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final g in FitnessGoal.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OptionTile(
            title: g.title,
            subtitle: g.subtitle,
            icon: goalIcon(g),
            selected: g == selected,
            onTap: () => onChanged(g == selected ? null : g),
          ),
        ),
    ],
  );
}

/// Sex is only used for the formula constant; "Prefer not to say" uses the midpoint.
enum SexAnswer { female, male, skip }

SexAnswer? sexAnswerOf(UserProfile p, {required bool answered}) => switch (p.sex) {
  SexForEstimate.female => SexAnswer.female,
  SexForEstimate.male => SexAnswer.male,
  null => answered ? SexAnswer.skip : null,
};

SexForEstimate? sexFromAnswer(SexAnswer? a) => switch (a) {
  SexAnswer.female => SexForEstimate.female,
  SexAnswer.male => SexForEstimate.male,
  _ => null,
};

class SexChoice extends StatelessWidget {
  const SexChoice({super.key, required this.selected, required this.onChanged});

  final SexAnswer? selected;
  final ValueChanged<SexAnswer> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (a, label) in const [
        (SexAnswer.male, 'Male'),
        (SexAnswer.female, 'Female'),
        (SexAnswer.skip, 'Prefer not to say'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OptionTile(title: label, centered: true, selected: a == selected, onTap: () => onChanged(a)),
        ),
    ],
  );
}

class AgeWheel extends StatelessWidget {
  const AgeWheel({super.key, required this.age, required this.onChanged});

  final int age;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Center(
    child: NumberWheel(
      values: [for (var a = 13; a <= 100; a++) a],
      selected: age.clamp(13, 100),
      labelOf: (a) => '$a',
      onChanged: onChanged,
      width: 140,
      semanticLabel: 'Age in years',
    ),
  );
}

/// Height + weight wheels with an Imperial / Metric toggle.
class BodyWheels extends StatelessWidget {
  const BodyWheels({
    super.key,
    required this.units,
    required this.heightCm,
    required this.weightKg,
    required this.onHeight,
    required this.onWeight,
    required this.onUnits,
  });

  final UnitSystem units;
  final double heightCm;
  final double weightKg;
  final ValueChanged<double> onHeight;
  final ValueChanged<double> onWeight;
  final ValueChanged<UnitSystem> onUnits;

  @override
  Widget build(BuildContext context) {
    final metric = units == UnitSystem.metric;
    final (ft, inch) = cmToFeetInches(heightCm);
    return Column(
      children: [
        SegmentedPill<UnitSystem>(
          options: const [UnitSystem.imperial, UnitSystem.metric],
          selected: units,
          labelOf: (u) => u.label,
          onChanged: onUnits,
        ),
        const SizedBox(height: NqSpace.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                const Text('Height', style: NqText.headline),
                const SizedBox(height: 8),
                if (metric)
                  NumberWheel(
                    values: [for (var c = 120; c <= 220; c++) c],
                    selected: heightCm.round().clamp(120, 220),
                    labelOf: (c) => '$c cm',
                    onChanged: (c) => onHeight(c.toDouble()),
                    semanticLabel: 'Height in centimetres',
                  )
                else
                  Row(
                    children: [
                      NumberWheel(
                        values: const [4, 5, 6, 7],
                        selected: ft.clamp(4, 7),
                        labelOf: (f) => '$f ft',
                        onChanged: (f) => onHeight(double.parse(feetInchesToCm(f, inch).toStringAsFixed(1))),
                        width: 78,
                        semanticLabel: 'Height, feet',
                      ),
                      NumberWheel(
                        values: [for (var i = 0; i <= 11; i++) i],
                        selected: inch,
                        labelOf: (i) => '$i in',
                        onChanged: (i) => onHeight(double.parse(feetInchesToCm(ft, i).toStringAsFixed(1))),
                        width: 78,
                        semanticLabel: 'Height, inches',
                      ),
                    ],
                  ),
              ],
            ),
            Column(
              children: [
                const Text('Weight', style: NqText.headline),
                const SizedBox(height: 8),
                WeightWheel(units: units, kg: weightKg, onChanged: onWeight),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// A weight wheel with its own Imperial / Metric switch (goal weight).
class WeightWithUnits extends StatelessWidget {
  const WeightWithUnits({
    super.key,
    required this.units,
    required this.kg,
    required this.onChanged,
    required this.onUnits,
  });

  final UnitSystem units;
  final double kg;
  final ValueChanged<double> onChanged;
  final ValueChanged<UnitSystem> onUnits;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SegmentedPill<UnitSystem>(
        options: const [UnitSystem.imperial, UnitSystem.metric],
        selected: units,
        labelOf: (u) => u.label,
        onChanged: onUnits,
      ),
      const SizedBox(height: NqSpace.xl),
      WeightWheel(units: units, kg: kg, onChanged: onChanged),
    ],
  );
}

class WeightWheel extends StatelessWidget {
  const WeightWheel({super.key, required this.units, required this.kg, required this.onChanged});

  final UnitSystem units;
  final double kg;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    // Keyed by unit so switching units builds a fresh wheel at the converted value.
    if (units == UnitSystem.metric) {
      return NumberWheel(
        key: const ValueKey('kg'),
        values: [for (var k = 35; k <= 250; k++) k],
        selected: kg.round().clamp(35, 250),
        labelOf: (k) => '$k kg',
        onChanged: (k) => onChanged(k.toDouble()),
        semanticLabel: 'Weight in kilograms',
      );
    }
    return NumberWheel(
      key: const ValueKey('lb'),
      values: [for (var l = 80; l <= 550; l++) l],
      selected: kgToLb(kg).round().clamp(80, 550),
      labelOf: (l) => '$l lb',
      onChanged: (l) => onChanged(double.parse(lbToKg(l.toDouble()).toStringAsFixed(1))),
      semanticLabel: 'Weight in pounds',
    );
  }
}

class ActivityChoice extends StatelessWidget {
  const ActivityChoice({super.key, required this.selected, required this.onChanged});

  final ActivityLevel? selected;
  final ValueChanged<ActivityLevel?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final a in ActivityLevel.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OptionTile(
            title: a.title,
            subtitle: a.description,
            selected: a == selected,
            onTap: () => onChanged(a == selected ? null : a),
          ),
        ),
    ],
  );
}

class WorkoutsWheel extends StatelessWidget {
  const WorkoutsWheel({super.key, required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Center(
    child: NumberWheel(
      values: const [0, 1, 2, 3, 4, 5, 6, 7],
      selected: days.clamp(0, 7),
      labelOf: (d) => d == 1 ? '1 day' : '$d days',
      onChanged: onChanged,
      width: 160,
      semanticLabel: 'Workout days per week',
    ),
  );
}

class HealthChoice extends StatelessWidget {
  const HealthChoice({super.key, required this.selected, required this.noneChosen, required this.onChanged});

  final Set<HealthConsideration> selected;
  final bool noneChosen;
  final void Function(Set<HealthConsideration> selected, {required bool none}) onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final h in HealthConsideration.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OptionTile(
            title: h.label,
            subtitle: h == HealthConsideration.medicalCondition
                ? 'For example diabetes, kidney disease, or an eating disorder (now or in the past)'
                : null,
            multi: true,
            selected: selected.contains(h),
            onTap: () {
              final next = {...selected};
              next.contains(h) ? next.remove(h) : next.add(h);
              onChanged(next, none: false);
            },
          ),
        ),
      OptionTile(
        title: 'None of these',
        multi: true,
        selected: noneChosen && selected.isEmpty,
        onTap: () => onChanged({}, none: true),
      ),
    ],
  );
}
