import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/food_item.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/settings.dart';
import 'package:nutriq/domain/models/user_profile.dart';
import 'package:nutriq/domain/starting_point.dart';

import '../support/test_app.dart';

Future<TestDeps> _launch(
  WidgetTester tester, {
  bool firstLaunch = true,
  List<Meal>? meals,
  UserProfile? profile,
}) async {
  final deps = await TestDeps.create(
    settings: AppSettings(onboardingComplete: !firstLaunch),
    meals: meals,
    profile: profile,
  );
  await deps.pumpApp(tester);
  return deps;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// Waits out the "Setting up your starting point" animation.
Future<void> _passBuilding(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first launch shows the welcome; skipping lands on Today without a goal', (tester) async {
    final deps = await _launch(tester);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Example'), findsOneWidget, reason: 'the preview is labeled as an example');

    await _tapText(tester, 'Skip setup — just start logging');
    expect(find.text('No calorie goal set'), findsOneWidget);
    expect(find.text('Set a calorie goal'), findsOneWidget);
    expect(find.text('No meals logged yet'), findsOneWidget);
    expect(deps.profile.settings.onboardingComplete, isTrue);
    expect(deps.profile.profile, isNull);
  });

  testWidgets('full onboarding builds an editable plan from the answers', (tester) async {
    final deps = await _launch(tester);
    await _tapText(tester, 'Get started');
    await _tapText(tester, 'Build strength');
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'Male');
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'Continue'); // age wheel default (30)
    await _tapText(tester, 'Continue'); // height & weight defaults (170 cm, 70 kg)
    await _tapText(tester, 'Skip'); // goal weight
    await _tapText(tester, 'Moderately active');
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'Continue'); // workouts
    await _tapText(tester, 'None of these');
    await _tapText(tester, 'Continue');
    await _passBuilding(tester);

    expect(find.text('Your starting point is ready'), findsOneWidget);
    final expected = StartingPoint.calculate(
      const UserProfile(
        age: 30,
        sex: SexForEstimate.male,
        heightCm: 170,
        weightKg: 70,
        activity: ActivityLevel.moderate,
        goal: FitnessGoal.buildStrength,
        workoutDaysPerWeek: 3,
      ),
    );
    await _tapText(tester, 'Use this plan');

    final saved = deps.profile.profile!;
    expect(saved.calorieGoal, expected.range);
    expect(saved.proteinTargetG, expected.proteinReferenceG);
    expect(saved.calorieGoal!.min, greaterThanOrEqualTo(CalorieBounds.floorFor(saved)));
    expect(find.text('Calories eaten · est.'), findsOneWidget);
  });

  testWidgets('under-18s get no calorie targets', (tester) async {
    final deps = await _launch(tester);
    await _tapText(tester, 'Get started');
    await _tapText(tester, 'Lose body fat');
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'Female');
    await _tapText(tester, 'Continue');
    // Age wheel: 30 → 16 (14 rows of 42 pt).
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, 14 * 42.0));
    await tester.pumpAndSettle();
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'Skip');
    await _tapText(tester, 'Lightly active');
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'None of these');
    await _tapText(tester, 'Continue');
    await _passBuilding(tester);

    expect(find.textContaining('under 18'), findsWidgets);
    expect(find.text('Use this plan'), findsNothing);
    await _tapText(tester, 'Continue');
    expect(deps.profile.profile!.age, 16);
    expect(deps.profile.profile!.calorieGoal, isNull);
    expect(deps.profile.profile!.proteinTargetG, isNull);
    expect(find.text('Set a calorie goal'), findsNothing);
  });

  testWidgets('goal weight can be switched between lb and kg', (tester) async {
    await _launch(tester);
    await _tapText(tester, 'Get started');
    await _tapText(tester, 'Skip for now'); // goal
    await _tapText(tester, 'Skip for now'); // sex
    await _tapText(tester, 'Continue'); // age
    await _tapText(tester, 'Imperial');
    await _tapText(tester, 'Continue'); // height & weight
    expect(find.text('Goal weight'), findsOneWidget);
    expect(find.text('154 lb'), findsOneWidget);
    expect(find.text('Metric'), findsOneWidget, reason: 'a unit switch on the goal weight step');

    await _tapText(tester, 'Metric');
    expect(find.text('70 kg'), findsOneWidget);
    expect(find.text('154 lb'), findsNothing);
  });

  testWidgets('a pregnancy answer skips calculated targets', (tester) async {
    final deps = await _launch(tester);
    await _tapText(tester, 'Get started');
    await _tapText(tester, 'Maintain');
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'Female');
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'Skip');
    await _tapText(tester, 'Lightly active');
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'Pregnant');
    await _tapText(tester, 'Continue');
    await _passBuilding(tester);

    expect(find.text('Use this plan'), findsNothing);
    await _tapText(tester, 'Continue');
    expect(deps.profile.profile!.health, contains(HealthConsideration.pregnant));
    expect(deps.profile.profile!.calorieGoal, isNull);
  });

  testWidgets('Today shows logged meals; the coach is labeled demo', (tester) async {
    final now = DateTime.now();
    await _launch(
      tester,
      firstLaunch: false,
      meals: [
        Meal(
          id: 'm',
          loggedAt: DateTime(now.year, now.month, now.day, now.hour, now.minute),
          type: MealType.lunch,
          source: MealSource.manual,
          items: const [FoodItem(id: 'f', name: 'Lentil soup', caloriesPerServing: 640, proteinPerServing: 30)],
        ),
      ],
    );
    expect(find.text('Lentil soup'), findsOneWidget);
    expect(find.text('640 kcal'), findsOneWidget);
    expect(find.text('1'), findsWidgets, reason: 'one-day streak');

    await tester.tap(find.text('Coach').last);
    await tester.pumpAndSettle();
    expect(find.text('Demo coach'), findsOneWidget);
    expect(find.text('How am I doing with my protein today?'), findsOneWidget);
  });

  testWidgets('the calorie editor never goes below the safe floor', (tester) async {
    const profile = UserProfile(
      age: 30,
      sex: SexForEstimate.male,
      heightCm: 180,
      weightKg: 80,
      activity: ActivityLevel.moderate,
      calorieGoal: CalorieRange(min: 1800, max: 2100),
    );
    final floor = CalorieBounds.floorFor(profile);
    expect(floor, 1800);
    await _launch(tester, firstLaunch: false, profile: profile);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await _tapText(tester, 'Calorie goal');
    expect(find.text('1,800 – 2,100 kcal/day'), findsOneWidget);

    // The low end's minus button is disabled at the floor.
    await tester.tap(find.byIcon(Icons.remove_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('1,800 – 2,100 kcal/day'), findsOneWidget);
  });

  testWidgets('deleting all data on this phone returns to the welcome screen', (tester) async {
    final deps = await _launch(tester, firstLaunch: false);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await _tapText(tester, 'Delete all data on this phone');
    await tester.tap(find.text('Delete everything').last);
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    expect(deps.profile.settings.onboardingComplete, isFalse);
    expect(deps.photos.deletedAll, isTrue);
  });
}
