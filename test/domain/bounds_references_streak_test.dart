import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/user_profile.dart';
import 'package:nutriq/domain/references.dart';
import 'package:nutriq/domain/starting_point.dart';
import 'package:nutriq/domain/streak.dart';

const _male = UserProfile(
  age: 30,
  sex: SexForEstimate.male,
  heightCm: 180,
  weightKg: 80,
  activity: ActivityLevel.moderate,
  goal: FitnessGoal.loseFat,
);

const _smallOlder = UserProfile(
  age: 60,
  sex: SexForEstimate.female,
  heightCm: 155,
  weightKg: 50,
  activity: ActivityLevel.sedentary,
  goal: FitnessGoal.loseFat,
);

void main() {
  group('CalorieBounds (regression: editors could go below the calculator floor)', () {
    test('floor is the higher of 1,200 and resting energy, rounded up to 50', () {
      expect(CalorieBounds.floorFor(_male), 1800); // resting energy 1,780
      expect(CalorieBounds.floorFor(_smallOlder), 1200); // resting energy ~1,008
    });

    test('without enough data the floor is 1,200', () {
      expect(CalorieBounds.floorFor(null), 1200);
      expect(CalorieBounds.floorFor(const UserProfile(age: 30, heightCm: 170)), 1200);
    });

    test('suggested ranges never start below the floor for any goal', () {
      for (final profile in [_male, _smallOlder]) {
        for (final goal in FitnessGoal.values) {
          final p = profile.copyWith(goal: goal);
          final range = StartingPoint.calculate(p).range!;
          expect(range.min, greaterThanOrEqualTo(CalorieBounds.floorFor(p)), reason: '$goal');
          expect(range.max - range.min, greaterThanOrEqualTo(100), reason: '$goal');
        }
      }
    });

    test('the no-deficit maintenance range is lifted to the floor', () {
      expect(StartingPoint.calculate(_smallOlder).range, const CalorieRange(min: 1200, max: 1300));
    });

    test('validate rejects ranges below the floor or inverted', () {
      expect(CalorieBounds.validate(const CalorieRange(min: 1500, max: 2000), _male), isNotNull);
      expect(CalorieBounds.validate(const CalorieRange(min: 1800, max: 1850), _male), isNotNull);
      expect(CalorieBounds.validate(const CalorieRange(min: 1800, max: 2200), _male), isNull);
      expect(CalorieBounds.validate(const CalorieRange(min: 2000, max: 6100), _male), isNotNull);
    });
  });

  group('MacroReferences', () {
    test('carbs and fat are derived from the calorie goal and protein reference', () {
      final refs = MacroReferences.forProfile(
        _male.copyWith(calorieGoal: const CalorieRange(min: 2750, max: 3000), proteinTargetG: 130),
      );
      expect(refs.protein, 130);
      expect(refs.carbs, 325);
      expect(refs.fat, 120);
    });

    test('no calorie goal means no carb or fat reference', () {
      final refs = MacroReferences.forProfile(_male.copyWith(proteinTargetG: 130));
      expect(refs.protein, 130);
      expect(refs.carbs, isNull);
      expect(refs.fat, isNull);
    });

    test('minors get no references at all', () {
      final refs = MacroReferences.forProfile(
        const UserProfile(age: 16, proteinTargetG: 90, calorieGoal: CalorieRange(min: 2000, max: 2200)),
      );
      expect([refs.protein, refs.carbs, refs.fat], everyElement(isNull));
    });
  });

  group('loggingStreak', () {
    final today = DateTime(2026, 10, 6);
    DateTime d(int day) => DateTime(2026, 10, day);

    test('counts consecutive logged days ending today', () {
      expect(loggingStreak({d(4), d(5), d(6)}, today), 3);
    });

    test('a not-yet-logged today keeps yesterday\'s streak alive', () {
      expect(loggingStreak({d(3), d(4), d(5)}, today), 3);
    });

    test('a gap resets the streak', () {
      expect(loggingStreak({d(2), d(4)}, today), 0);
      expect(loggingStreak({}, today), 0);
    });
  });

  test('Meal name overrides the meal-type title and survives JSON', () {
    final meal = Meal(
      id: 'm',
      loggedAt: DateTime(2026, 10, 6, 12),
      type: MealType.lunch,
      source: MealSource.manual,
      items: const [],
      name: 'Chicken bowl',
    );
    expect(meal.title, 'Chicken bowl');
    expect(Meal.fromJson(meal.toJson()).name, 'Chicken bowl');
    expect(meal.copyWith(name: '').title, 'Lunch');
  });
}
