import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/food_item.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/features/meal_editor/meal_editor_screen.dart';
import 'package:nutriq/widgets/controls.dart';

import '../support/test_app.dart';

const _rice = FoodItem(id: 'r', name: 'Brown rice', caloriesPerServing: 200, carbsPerServing: 45);

void main() {
  MealEditorScreen demoReview() =>
      const MealEditorScreen(initialItems: [_rice], source: MealSource.demoScan, demoSampleName: 'Test bowl');

  testWidgets('demo review is labeled and values are estimates', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpPushed(tester, demoReview());

    expect(find.textContaining('Demo result'), findsOneWidget);
    expect(find.text('Estimate'), findsWidgets);
    expect(find.text('Brown rice'), findsOneWidget);
  });

  testWidgets('changing servings updates the total and saving logs the meal', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpPushed(tester, demoReview());

    expect(find.text('200'), findsWidgets);
    await tester.tap(
      find.descendant(of: find.byType(StepperControl), matching: find.byIcon(Icons.add_rounded)),
    );
    await tester.pumpAndSettle();
    expect(find.text('250'), findsWidgets);

    await tester.tap(find.text('Save to log'));
    await tester.pumpAndSettle();
    expect(deps.log.meals.single.source, MealSource.demoScan);
    expect(deps.log.meals.single.totals.calories, 250);
    expect(find.text('open'), findsOneWidget, reason: 'editor closed after saving');
  });

  testWidgets('foods can be saved without logging a meal', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpPushed(tester, demoReview());

    await tester.ensureVisible(find.text('Save foods without logging'));
    await tester.tap(find.text('Save foods without logging'));
    await tester.pumpAndSettle();
    expect(deps.log.meals, isEmpty);
    expect(deps.log.savedFoods.single.item.name, 'Brown rice');
  });

  testWidgets('invalid calories show a validation message instead of crashing', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpPushed(tester, demoReview());

    await tester.tap(find.text('Brown rice'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Calories per serving'), 'abc');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number'), findsOneWidget);
  });

  testWidgets('removing every food disables saving and shows an empty state', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpPushed(tester, demoReview());

    await tester.drag(find.text('Brown rice'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('No foods yet'), findsOneWidget);
    await tester.tap(find.text('Save to log'));
    await tester.pumpAndSettle();
    expect(deps.log.meals, isEmpty);
  });
}
