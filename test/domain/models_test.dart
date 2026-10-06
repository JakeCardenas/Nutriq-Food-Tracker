import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/food_item.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/settings.dart';
import 'package:nutriq/domain/models/user_profile.dart';

FoodItem _item({double servings = 1, double kcal = 200}) => FoodItem(
  id: 'f1',
  name: 'Rice',
  servings: servings,
  servingLabel: '1 cup (158 g)',
  caloriesPerServing: kcal,
  proteinPerServing: 4,
  carbsPerServing: 45,
  fatPerServing: 0.5,
);

void main() {
  group('FoodItem', () {
    test('scales nutrition by servings', () {
      final totals = _item(servings: 1.5).totals;
      expect(totals.calories, 300);
      expect(totals.protein, 6);
      expect(totals.carbs, 67.5);
    });

    test('zero or negative servings produce zero totals, never NaN', () {
      expect(_item(servings: 0).totals.calories, 0);
      expect(_item(servings: -1).totals.calories, 0);
    });

    test('round-trips through JSON', () {
      final item = _item(servings: 2).copyWith(confidence: 0.4);
      expect(FoodItem.fromJson(item.toJson()), item);
    });
  });

  group('Meal', () {
    final meal = Meal(
      id: 'm1',
      loggedAt: DateTime(2026, 10, 6, 12, 30),
      type: MealType.lunch,
      source: MealSource.demoScan,
      photoPath: '/tmp/p.jpg',
      items: [
        _item(),
        _item(servings: 2).copyWith(id: 'f2', name: 'Chicken'),
      ],
    );

    test('sums item totals', () {
      expect(meal.totals.calories, 600);
    });

    test('round-trips through JSON', () {
      expect(Meal.fromJson(meal.toJson()), meal);
    });

    test('title uses meal type label', () {
      expect(meal.title, 'Lunch');
    });

    test('summary lists food names', () {
      expect(meal.itemSummary, 'Rice, Chicken');
    });
  });

  group('MealType.suggestFor', () {
    test('suggests by time of day', () {
      expect(MealType.suggestFor(DateTime(2026, 1, 1, 8)), MealType.breakfast);
      expect(MealType.suggestFor(DateTime(2026, 1, 1, 12, 30)), MealType.lunch);
      expect(MealType.suggestFor(DateTime(2026, 1, 1, 15, 30)), MealType.snack);
      expect(MealType.suggestFor(DateTime(2026, 1, 1, 19)), MealType.dinner);
      expect(MealType.suggestFor(DateTime(2026, 1, 1, 23, 30)), MealType.snack);
    });
  });

  group('UserProfile', () {
    test('round-trips through JSON including health considerations and goal', () {
      const profile = UserProfile(
        age: 30,
        sex: SexForEstimate.female,
        heightCm: 165,
        weightKg: 62,
        goalWeightKg: 60,
        activity: ActivityLevel.light,
        goal: FitnessGoal.buildStrength,
        workoutDaysPerWeek: 3,
        health: {HealthConsideration.breastfeeding},
        calorieGoal: CalorieRange(min: 1900, max: 2100),
        proteinTargetG: 100,
      );
      expect(UserProfile.fromJson(profile.toJson()), profile);
    });

    test('copyWith can clear nullable fields', () {
      const profile = UserProfile(age: 30, calorieGoal: CalorieRange(min: 1, max: 2));
      final cleared = profile.copyWith(calorieGoal: null);
      expect(cleared.calorieGoal, isNull);
      expect(cleared.age, 30);
    });
  });

  group('AppSettings', () {
    test('defaults to metric, midnight, onboarding not complete', () {
      const s = AppSettings();
      expect(s.units, UnitSystem.metric);
      expect(s.dayStartHour, 0);
      expect(s.onboardingComplete, isFalse);
    });

    test('round-trips through JSON', () {
      const s = AppSettings(units: UnitSystem.imperial, dayStartHour: 4, onboardingComplete: true);
      expect(AppSettings.fromJson(s.toJson()), s);
    });
  });
}
