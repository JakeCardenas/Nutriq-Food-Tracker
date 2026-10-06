import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/user_profile.dart';
import 'package:nutriq/domain/starting_point.dart';

const _adultMale = UserProfile(
  age: 30,
  sex: SexForEstimate.male,
  heightCm: 180,
  weightKg: 80,
  activity: ActivityLevel.moderate,
  goal: FitnessGoal.maintain,
);

StartingPointResult _calc(UserProfile p) => StartingPoint.calculate(p);

void main() {
  group('eligible adults', () {
    test('Mifflin–St Jeor BMR and maintenance for a male reference', () {
      final r = _calc(_adultMale);
      expect(r.eligibility, TargetEligibility.eligible);
      expect(r.bmr, 1780);
      expect(r.maintenance, 2760);
      expect(r.sexMidpointUsed, isFalse);
    });

    test('goal ranges are rounded to 50 kcal', () {
      expect(_calc(_adultMale).range, const CalorieRange(min: 2650, max: 2850));
      expect(_calc(_adultMale.copyWith(goal: FitnessGoal.loseFat)).range, const CalorieRange(min: 2250, max: 2500));
      expect(_calc(_adultMale.copyWith(goal: FitnessGoal.gainMuscle)).range, const CalorieRange(min: 2900, max: 3100));
      expect(
        _calc(_adultMale.copyWith(goal: FitnessGoal.buildStrength)).range,
        const CalorieRange(min: 2750, max: 3000),
      );
    });

    test('protein reference depends on goal', () {
      expect(_calc(_adultMale.copyWith(goal: FitnessGoal.gainMuscle)).proteinReferenceG, 130);
      expect(_calc(_adultMale).proteinReferenceG, 95);
    });

    test('female constant', () {
      expect(_calc(_adultMale.copyWith(sex: SexForEstimate.female)).maintenance, 2500);
    });

    test('skipping sex uses the midpoint and reports the uncertainty', () {
      final r = _calc(_adultMale.copyWith(sex: null));
      expect(r.maintenance, 2630);
      expect(r.sexMidpointUsed, isTrue);
      expect(r.uncertaintyKcal, 130);
      expect(r.assumptions.join(' '), contains('midpoint'));
    });

    test('no deficit is suggested when maintenance is already near the floor', () {
      final r = _calc(
        const UserProfile(
          age: 60,
          sex: SexForEstimate.female,
          heightCm: 155,
          weightKg: 50,
          activity: ActivityLevel.sedentary,
          goal: FitnessGoal.loseFat,
        ),
      );
      expect(r.maintenance, 1210);
      expect(r.deficitNotSuggested, isTrue);
      expect(r.range, const CalorieRange(min: 1200, max: 1300));
    });

    test('a goal weight implying a very low BMI raises a gentle note', () {
      expect(_calc(_adultMale.copyWith(goalWeightKg: 50.0)).lowGoalWeightNote, isTrue);
      expect(_calc(_adultMale.copyWith(goalWeightKg: 70.0)).lowGoalWeightNote, isFalse);
    });

    test('no goal chosen falls back to a maintenance range', () {
      expect(_calc(_adultMale.copyWith(goal: null)).range, const CalorieRange(min: 2650, max: 2850));
    });
  });

  group('safeguards', () {
    test('under 18 gets no calorie or protein numbers', () {
      final r = _calc(_adultMale.copyWith(age: 16, goal: FitnessGoal.loseFat));
      expect(r.eligibility, TargetEligibility.under18);
      expect(r.range, isNull);
      expect(r.maintenance, isNull);
      expect(r.proteinReferenceG, isNull);
    });

    test('pregnancy, breastfeeding or a medical condition gets no numbers', () {
      for (final h in HealthConsideration.values) {
        final r = _calc(_adultMale.copyWith(health: {h}));
        expect(r.eligibility, TargetEligibility.healthConsideration, reason: h.name);
        expect(r.range, isNull);
      }
    });

    test('under-18 check wins over missing data', () {
      expect(_calc(const UserProfile(age: 15)).eligibility, TargetEligibility.under18);
    });

    test('missing inputs are listed', () {
      final r = _calc(const UserProfile(age: 30, heightCm: 170));
      expect(r.eligibility, TargetEligibility.needsMoreInfo);
      expect(r.missing, [MissingInput.weight, MissingInput.activity]);
      expect(r.range, isNull);
    });
  });
}
