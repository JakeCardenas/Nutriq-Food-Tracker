import 'dart:math' as math;

import 'models/user_profile.dart';

/// Whether personal calorie numbers may be shown, and if not, why.
enum TargetEligibility { eligible, under18, healthConsideration, needsMoreInfo }

enum MissingInput {
  age('age'),
  height('height'),
  weight('current weight'),
  activity('activity level');

  const MissingInput(this.label);
  final String label;
}

class StartingPointResult {
  const StartingPointResult({
    required this.eligibility,
    this.missing = const [],
    this.bmr,
    this.maintenance,
    this.range,
    this.proteinReferenceG,
    this.sexMidpointUsed = false,
    this.uncertaintyKcal,
    this.deficitNotSuggested = false,
    this.lowGoalWeightNote = false,
    this.assumptions = const [],
  });

  final TargetEligibility eligibility;
  final List<MissingInput> missing;

  /// Estimated resting energy (kcal/day).
  final int? bmr;

  /// Estimated maintenance calories (kcal/day), rounded to 10.
  final int? maintenance;

  /// Suggested, editable goal range for the chosen goal.
  final CalorieRange? range;
  final int? proteinReferenceG;
  final bool sexMidpointUsed;

  /// ± kcal of extra uncertainty when the sex constant was skipped.
  final int? uncertaintyKcal;
  final bool deficitNotSuggested;
  final bool lowGoalWeightNote;

  /// Plain-language explanation of every input and adjustment used.
  final List<String> assumptions;

  bool get hasNumbers => eligibility == TargetEligibility.eligible;
}

/// Builds the onboarding "Your starting point" estimate.
///
/// Uses the Mifflin–St Jeor equation × an activity multiplier, then applies
/// a modest goal adjustment. Results are references, not prescriptions.
abstract final class StartingPoint {
  static const _maleConstant = 5;
  static const _femaleConstant = -161;
  static const _midpointConstant = -78;
  static const _minimumIntake = 1200;

  static StartingPointResult calculate(UserProfile p) {
    if (p.isMinor) return const StartingPointResult(eligibility: TargetEligibility.under18);
    if (p.hasHealthConsideration) {
      return const StartingPointResult(eligibility: TargetEligibility.healthConsideration);
    }

    final missing = [
      if (p.age == null) MissingInput.age,
      if (p.heightCm == null) MissingInput.height,
      if (p.weightKg == null) MissingInput.weight,
      if (p.activity == null) MissingInput.activity,
    ];
    if (missing.isNotEmpty) {
      return StartingPointResult(eligibility: TargetEligibility.needsMoreInfo, missing: missing);
    }

    final heightCm = p.heightCm!, weightKg = p.weightKg!, activity = p.activity!;
    final goal = p.goal ?? FitnessGoal.maintain;

    final sexConstant = _sexConstant(p.sex);
    final bmr = restingEnergy(p)!;
    final maintenance = _round(bmr * activity.factor, 10);
    final uncertainty = p.sex == null ? _round(83 * activity.factor, 10) : null;

    final floor = math.max(_minimumIntake.toDouble(), bmr);
    final floorKcal = CalorieBounds.floorFor(p);
    var deficitNotSuggested = false;
    CalorieRange around(int lowOffset, int highOffset) {
      final low = math.max(_round(maintenance + lowOffset, 50), floorKcal);
      return CalorieRange(min: low, max: math.max(low + 100, _round(maintenance + highOffset, 50)));
    }

    final CalorieRange range;
    switch (goal) {
      case FitnessGoal.loseFat:
        if (maintenance - 250 < floor) {
          deficitNotSuggested = true;
          range = around(-100, 100);
        } else {
          final low = math.max(_round(maintenance - 500, 50), floorKcal);
          final high = math.max(low + 100, _round(maintenance - 250, 50));
          range = CalorieRange(min: low, max: high);
        }
      case FitnessGoal.gainMuscle:
        range = around(150, 350);
      case FitnessGoal.buildStrength:
        range = around(0, 250);
      case FitnessGoal.maintain || FitnessGoal.generalFitness || FitnessGoal.eatConsistently:
        range = around(-100, 100);
    }

    final proteinPerKg = switch (goal) {
      FitnessGoal.loseFat || FitnessGoal.gainMuscle || FitnessGoal.buildStrength => 1.6,
      _ => 1.2,
    };
    final protein = _round(weightKg * proteinPerKg, 5);

    final goalWeight = p.goalWeightKg;
    final heightM = heightCm / 100;
    final lowGoalWeight = goalWeight != null && goalWeight / (heightM * heightM) < 18.5;

    final assumptions = [
      'Formula: Mifflin–St Jeor resting energy = 10 × weight (kg) + 6.25 × height (cm) − 5 × age + a constant.',
      if (p.sex == null)
        'You skipped sex, so we used the midpoint of the formula’s two constants. '
            'Your true maintenance could differ by about ±$uncertainty kcal.'
      else
        'Formula constant for ${p.sex!.label.toLowerCase()}: ${sexConstant > 0 ? '+' : '−'}${sexConstant.abs()}.',
      'Activity: ${activity.title} (× ${activity.factor}).',
      switch (goal) {
        FitnessGoal.loseFat =>
          deficitNotSuggested
              ? 'Your estimated maintenance is already close to a minimum we’d suggest, '
                    'so we’re not recommending a lower range. A professional can help you plan.'
              : 'Lose body fat: 250–500 kcal below maintenance, never below '
                    '${_ceil(floor, 50)} kcal (your estimated resting energy or 1,200, whichever is higher).',
        FitnessGoal.gainMuscle => 'Gain muscle: 150–350 kcal above maintenance.',
        FitnessGoal.buildStrength => 'Build strength: maintenance up to 250 kcal above.',
        _ => '${goal.title}: about ±100 kcal around maintenance.',
      },
      'Protein reference: $proteinPerKg g per kg of current body weight, a common sports-nutrition guideline.',
      'Rounded to the nearest 50 kcal. Real needs vary with genetics, sleep, stress, and how activity is counted.',
    ];

    return StartingPointResult(
      eligibility: TargetEligibility.eligible,
      bmr: bmr.round(),
      maintenance: maintenance,
      range: range,
      proteinReferenceG: protein,
      sexMidpointUsed: p.sex == null,
      uncertaintyKcal: uncertainty,
      deficitNotSuggested: deficitNotSuggested,
      lowGoalWeightNote: lowGoalWeight,
      assumptions: assumptions,
    );
  }

  static int _sexConstant(SexForEstimate? sex) => switch (sex) {
    SexForEstimate.male => _maleConstant,
    SexForEstimate.female => _femaleConstant,
    null => _midpointConstant,
  };

  /// Mifflin–St Jeor resting energy (kcal/day), or null without age, height and weight.
  static double? restingEnergy(UserProfile? p) {
    if (p == null || p.age == null || p.heightCm == null || p.weightKg == null) return null;
    return 10 * p.weightKg! + 6.25 * p.heightCm! - 5 * p.age! + _sexConstant(p.sex);
  }

  static int _round(num v, int step) => (v / step).round() * step;
  static int _ceil(num v, int step) => (v / step).ceil() * step;
}

/// The single source of truth for which calorie goals Nutriq will suggest or save.
///
/// Used by the calculator, both range editors and [ProfileController.setCalorieGoal],
/// so the editable low end can never undercut what the calculator would allow.
abstract final class CalorieBounds {
  static const absoluteMinimum = 1200;
  static const maximum = 6000;
  static const minimumSpread = 50;

  /// max(1,200, estimated resting energy), rounded up to the nearest 50 kcal.
  static int floorFor(UserProfile? p) {
    final bmr = StartingPoint.restingEnergy(p) ?? 0;
    return StartingPoint._ceil(math.max(absoluteMinimum.toDouble(), bmr), 50);
  }

  /// A user-facing reason the range can't be saved, or null when it's fine.
  static String? validate(CalorieRange range, UserProfile? p) {
    final floor = floorFor(p);
    if (range.min < floor) {
      return 'The low end can’t go below $floor kcal — the higher of 1,200 and your estimated resting energy.';
    }
    if (range.max - range.min < minimumSpread * 2) {
      return 'Leave at least 100 kcal between the low and high end.';
    }
    if (range.max > maximum) return 'The high end can’t go above $maximum kcal.';
    return null;
  }
}
