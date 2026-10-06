import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/units.dart';
import '../../widgets/controls.dart';
import '../meal_editor/food_item_form.dart' show parseNumber;

/// Profile inputs shared by onboarding and Settings → Edit profile.
/// Every field is optional and explains why it's asked.

class WhyText extends StatelessWidget {
  const WhyText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
    child: Text(text, style: NqText.footnote),
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: NqSpace.xl, bottom: NqSpace.sm, left: 4),
    child: Text(text, style: NqText.headline),
  );
}

IconData goalIcon(FitnessGoal g) => switch (g) {
  FitnessGoal.loseFat => Icons.trending_down_rounded,
  FitnessGoal.maintain => Icons.balance_rounded,
  FitnessGoal.gainMuscle => Icons.trending_up_rounded,
  FitnessGoal.buildStrength => Icons.fitness_center_rounded,
  FitnessGoal.generalFitness => Icons.directions_run_rounded,
  FitnessGoal.eatConsistently => Icons.event_repeat_rounded,
};

class GoalPicker extends StatelessWidget {
  const GoalPicker({super.key, required this.selected, required this.onChanged});

  final FitnessGoal? selected;
  final ValueChanged<FitnessGoal?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final g in FitnessGoal.values)
        Padding(
          padding: const EdgeInsets.only(bottom: NqSpace.sm),
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

class ActivityPicker extends StatelessWidget {
  const ActivityPicker({
    super.key,
    required this.selected,
    required this.workoutDays,
    required this.onChanged,
    required this.onWorkoutDays,
  });

  final ActivityLevel? selected;
  final int? workoutDays;
  final ValueChanged<ActivityLevel?> onChanged;
  final ValueChanged<int?> onWorkoutDays;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final a in ActivityLevel.values)
        Padding(
          padding: const EdgeInsets.only(bottom: NqSpace.sm),
          child: OptionTile(
            title: a.title,
            subtitle: a.description,
            selected: a == selected,
            onTap: () => onChanged(a == selected ? null : a),
          ),
        ),
      const WhyText('Activity is the biggest multiplier in the estimate. Pick your typical week.'),
      const FieldLabel('Workout days per week (optional)'),
      ChoiceChips<int>(
        options: const [0, 1, 2, 3, 4, 5, 6, 7],
        selected: workoutDays,
        labelOf: (d) => '$d',
        onSelected: (d) => onWorkoutDays(d == workoutDays ? null : d),
      ),
      const WhyText('Helps the coach with consistency tips. It doesn’t change your calorie estimate.'),
    ],
  );
}

class HealthCheck extends StatelessWidget {
  const HealthCheck({super.key, required this.selected, required this.noneChosen, required this.onChanged});

  final Set<HealthConsideration> selected;
  final bool noneChosen;
  final void Function(Set<HealthConsideration> selected, {required bool none}) onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final h in HealthConsideration.values)
        Padding(
          padding: const EdgeInsets.only(bottom: NqSpace.sm),
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

/// Age, sex-for-formula, units, height, weight and goal weight.
/// Wrap in a [Form] and validate before continuing.
class AboutYouFields extends StatefulWidget {
  const AboutYouFields({
    super.key,
    required this.profile,
    required this.units,
    required this.onChanged,
    required this.onUnitsChanged,
  });

  final UserProfile profile;
  final UnitSystem units;
  final ValueChanged<UserProfile> onChanged;
  final ValueChanged<UnitSystem> onUnitsChanged;

  @override
  State<AboutYouFields> createState() => _AboutYouFieldsState();
}

enum _SexChoice { female, male, skip }

class _AboutYouFieldsState extends State<AboutYouFields> {
  late final _age = TextEditingController(text: widget.profile.age?.toString() ?? '');
  final _heightCm = TextEditingController();
  final _feet = TextEditingController();
  final _inches = TextEditingController();
  final _weight = TextEditingController();
  final _goalWeight = TextEditingController();
  _SexChoice? _sex;

  bool get _metric => widget.units == UnitSystem.metric;

  @override
  void initState() {
    super.initState();
    _sex = switch (widget.profile.sex) {
      SexForEstimate.female => _SexChoice.female,
      SexForEstimate.male => _SexChoice.male,
      null => null,
    };
    _fillMeasurements();
  }

  @override
  void didUpdateWidget(AboutYouFields old) {
    super.didUpdateWidget(old);
    if (old.units != widget.units) _fillMeasurements();
  }

  void _fillMeasurements() {
    final p = widget.profile;
    String kgText(double? kg) => kg == null ? '' : (_metric ? _trim(kg) : kgToLb(kg).round().toString());
    _heightCm.text = p.heightCm == null ? '' : p.heightCm!.round().toString();
    if (p.heightCm != null) {
      final (ft, inch) = cmToFeetInches(p.heightCm!);
      _feet.text = '$ft';
      _inches.text = '$inch';
    } else {
      _feet.text = '';
      _inches.text = '';
    }
    _weight.text = kgText(p.weightKg);
    _goalWeight.text = kgText(p.goalWeightKg);
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  @override
  void dispose() {
    for (final c in [_age, _heightCm, _feet, _inches, _weight, _goalWeight]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── parsing ───────────────────────────────────────────────────────────

  int? get _ageValue {
    final n = int.tryParse(_age.text.trim());
    return n != null && n >= 13 && n <= 100 ? n : null;
  }

  double? get _heightValue {
    if (_metric) {
      final cm = parseNumber(_heightCm.text);
      return cm != null && cm >= 100 && cm <= 250 ? cm : null;
    }
    final ft = int.tryParse(_feet.text.trim());
    final inch = _inches.text.trim().isEmpty ? 0 : int.tryParse(_inches.text.trim());
    if (ft == null || inch == null || inch < 0 || inch > 11) return null;
    final cm = feetInchesToCm(ft, inch);
    return cm >= 100 && cm <= 250 ? double.parse(cm.toStringAsFixed(1)) : null;
  }

  double? _weightValue(String text) {
    final n = parseNumber(text);
    if (n == null) return null;
    final kg = _metric ? n : lbToKg(n);
    return kg >= 30 && kg <= 300 ? double.parse(kg.toStringAsFixed(1)) : null;
  }

  void _emit() {
    widget.onChanged(
      widget.profile.copyWith(
        age: _ageValue,
        sex: switch (_sex) {
          _SexChoice.female => SexForEstimate.female,
          _SexChoice.male => SexForEstimate.male,
          _ => null,
        },
        heightCm: _heightValue,
        weightKg: _weightValue(_weight.text),
        goalWeightKg: _weightValue(_goalWeight.text),
      ),
    );
  }

  // ── validators (empty is always fine) ─────────────────────────────────

  String? _validateAge(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return _ageValue == null ? 'Nutriq is for ages 13+. Enter 13–100, or leave it blank.' : null;
  }

  String? _validateHeight(String? _) {
    final empty = _metric
        ? _heightCm.text.trim().isEmpty
        : _feet.text.trim().isEmpty && _inches.text.trim().isEmpty;
    if (empty) return null;
    return _heightValue == null
        ? (_metric ? 'Enter 100–250 cm' : 'Enter a height between 3′4″ and 8′2″')
        : null;
  }

  String? _validateWeight(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return _weightValue(v) == null ? (_metric ? 'Enter 30–300 kg' : 'Enter 66–660 lb') : null;
  }

  @override
  Widget build(BuildContext context) {
    const numbers = TextInputType.numberWithOptions(decimal: true);
    final w = _metric ? 'kg' : 'lb';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _age,
          decoration: const InputDecoration(labelText: 'Age'),
          keyboardType: TextInputType.number,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _validateAge,
          onChanged: (_) => _emit(),
        ),
        const WhyText('Used in the calorie formula and to keep guidance age-appropriate.'),
        const FieldLabel('Sex for the formula (optional)'),
        ChoiceChips<_SexChoice>(
          options: _SexChoice.values,
          selected: _sex,
          labelOf: (s) => switch (s) {
            _SexChoice.female => 'Female',
            _SexChoice.male => 'Male',
            _SexChoice.skip => 'Prefer not to say',
          },
          onSelected: (s) {
            setState(() => _sex = s);
            _emit();
          },
        ),
        const WhyText(
          'The formula we use (Mifflin–St Jeor) has a different constant for male and female bodies. '
          'If you skip this, we use the midpoint and tell you the estimate is less precise.',
        ),
        const FieldLabel('Units'),
        ChoiceChips<UnitSystem>(
          options: UnitSystem.values,
          selected: widget.units,
          labelOf: (u) => u == UnitSystem.metric ? 'cm · kg' : 'ft · lb',
          onSelected: widget.onUnitsChanged,
        ),
        const SizedBox(height: NqSpace.lg),
        if (_metric)
          TextFormField(
            controller: _heightCm,
            decoration: const InputDecoration(labelText: 'Height (cm)'),
            keyboardType: numbers,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _validateHeight,
            onChanged: (_) => _emit(),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _feet,
                  decoration: const InputDecoration(labelText: 'Height (ft)'),
                  keyboardType: TextInputType.number,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validateHeight,
                  onChanged: (_) => _emit(),
                ),
              ),
              const SizedBox(width: NqSpace.sm),
              Expanded(
                child: TextFormField(
                  controller: _inches,
                  decoration: const InputDecoration(labelText: 'Height (in)'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _emit(),
                ),
              ),
            ],
          ),
        const SizedBox(height: NqSpace.md),
        TextFormField(
          controller: _weight,
          decoration: InputDecoration(labelText: 'Weight ($w)'),
          keyboardType: numbers,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _validateWeight,
          onChanged: (_) => _emit(),
        ),
        const WhyText('Height and weight are used only for your estimate. They stay on this phone.'),
        const SizedBox(height: NqSpace.md),
        TextFormField(
          controller: _goalWeight,
          decoration: InputDecoration(labelText: 'Goal weight ($w, optional)'),
          keyboardType: numbers,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _validateWeight,
          onChanged: (_) => _emit(),
        ),
        const WhyText('Gives the coach context. Nutriq never predicts when you’ll reach it.'),
      ],
    );
  }
}
