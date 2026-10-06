import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/app/nutriq_app.dart';
import 'package:nutriq/domain/models/food_item.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/settings.dart';

import '../support/test_app.dart';

Future<TestDeps> _launch(WidgetTester tester, {bool firstLaunch = true, List<Meal>? meals}) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  final deps = await TestDeps.create(
    settings: AppSettings(onboardingComplete: !firstLaunch),
    meals: meals,
  );
  await tester.pumpWidget(deps.wrap(const NutriqApp()));
  await tester.pumpAndSettle();
  return deps;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  if (find.text(text).evaluate().isEmpty) {
    await tester.scrollUntilVisible(find.text(text), 200, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first launch shows onboarding; skipping lands on Today without a goal', (tester) async {
    final deps = await _launch(tester);
    expect(find.text('Set up my starting point'), findsOneWidget);

    await _tapText(tester, 'Skip — just start logging');
    expect(find.text('Scan meal'), findsOneWidget);
    expect(find.text('No calorie goal set'), findsOneWidget);
    expect(deps.profile.settings.onboardingComplete, isTrue);
  });

  testWidgets('full onboarding produces an editable starting point', (tester) async {
    final deps = await _launch(tester);
    await _tapText(tester, 'Set up my starting point');

    await _tapText(tester, 'Build strength');
    await _tapText(tester, 'Continue');

    await _enter(tester, 'Age', '30');
    await _tapText(tester, 'Male');
    await _enter(tester, 'Height (cm)', '180');
    await _enter(tester, 'Weight (kg)', '80');
    await _tapText(tester, 'Continue');

    await _tapText(tester, 'Moderately active');
    await _tapText(tester, 'Continue');

    await _tapText(tester, 'None of these');
    await _tapText(tester, 'Continue');

    expect(find.text('Your starting point'), findsOneWidget);
    expect(find.textContaining('2,760'), findsWidgets);
    expect(find.textContaining('not medical advice'), findsOneWidget);

    await _tapText(tester, 'Use this range');
    expect(find.text('Scan meal'), findsOneWidget);
    expect(deps.profile.profile!.calorieGoal!.min, 2750);
    expect(deps.profile.profile!.proteinTargetG, 130);
    expect(find.textContaining('to your range'), findsOneWidget);
  });

  testWidgets('under-18 users get no calorie targets', (tester) async {
    final deps = await _launch(tester);
    await _tapText(tester, 'Set up my starting point');
    await _tapText(tester, 'Lose body fat');
    await _tapText(tester, 'Continue');
    await _enter(tester, 'Age', '16');
    await _enter(tester, 'Height (cm)', '165');
    await _enter(tester, 'Weight (kg)', '60');
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'Lightly active');
    await _tapText(tester, 'Continue');
    await _tapText(tester, 'Continue');

    expect(find.textContaining('under 18'), findsWidgets);
    expect(find.text('Use this range'), findsNothing);
    await _tapText(tester, 'Start logging');
    expect(deps.profile.profile!.calorieGoal, isNull);
  });

  testWidgets('invalid age blocks continue with a clear message', (tester) async {
    await _launch(tester);
    await _tapText(tester, 'Set up my starting point');
    await _tapText(tester, 'Continue');
    await _enter(tester, 'Age', '7');
    await _tapText(tester, 'Continue');
    expect(find.textContaining('13'), findsWidgets);
    expect(find.text('About you'), findsOneWidget);
  });

  testWidgets('Today shows logged meals and the coach tab is labeled demo', (tester) async {
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
          items: const [
            FoodItem(id: 'f', name: 'Lentil soup', caloriesPerServing: 640, proteinPerServing: 30),
          ],
        ),
      ],
    );
    expect(find.text('Lentil soup'), findsOneWidget);
    expect(find.text('640'), findsWidgets);

    await tester.tap(find.text('Coach').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Demo coach'), findsWidgets);
    expect(find.text('How am I doing with my protein today?'), findsOneWidget);
  });

  testWidgets('Delete everything returns to onboarding', (tester) async {
    final deps = await _launch(tester, firstLaunch: false);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await _tapText(tester, 'Delete all data');
    await tester.tap(find.text('Delete everything').last);
    await tester.pumpAndSettle();
    expect(find.text('Set up my starting point'), findsOneWidget);
    expect(deps.profile.settings.onboardingComplete, isFalse);
  });
}
