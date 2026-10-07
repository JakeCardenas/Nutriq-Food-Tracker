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
    expect(find.text('Brown rice'), findsNWidgets(2), reason: 'meal name (from the foods) and the ingredient');
  });

  testWidgets('changing servings updates the total and saving logs the meal', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpPushed(tester, demoReview());

    expect(find.text('200'), findsWidgets);
    // The last stepper belongs to the ingredient (the first scales the whole meal).
    await tester.tap(find.descendant(of: find.byType(StepperControl), matching: find.byIcon(Icons.add_rounded)).last);
    await tester.pumpAndSettle();
    expect(find.text('250'), findsWidgets);

    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    expect(deps.log.meals.single.source, MealSource.demoScan);
    expect(deps.log.meals.single.totals.calories, 250);
    expect(find.text('open'), findsOneWidget, reason: 'editor closed after saving');
  });

  testWidgets('foods can be saved without logging a meal', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpPushed(tester, demoReview());

    await tester.tap(find.text('Save foods'));
    await tester.pumpAndSettle();
    expect(deps.log.meals, isEmpty);
    expect(deps.log.savedFoods.single.item.name, 'Brown rice');
  });

  testWidgets('invalid calories show a validation message instead of crashing', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpPushed(tester, demoReview());

    await tester.tap(find.text('Brown rice').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Calories per serving'), 'abc');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number'), findsOneWidget);
  });

  testWidgets('removing every food disables saving and shows an empty state', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpPushed(tester, demoReview());

    await tester.drag(find.text('Brown rice').last, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('describe-field')), findsOneWidget, reason: 'empty: describe what you ate');
    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    expect(deps.log.meals, isEmpty);
  });

  testWidgets('the meal portion stepper scales every ingredient', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpPushed(
      tester,
      const MealEditorScreen(
        initialItems: [
          _rice,
          FoodItem(id: 'c', name: 'Chicken', caloriesPerServing: 100, proteinPerServing: 20),
        ],
        source: MealSource.scan,
      ),
    );
    expect(find.text('300'), findsWidgets);
    await tester.tap(find.descendant(of: find.byType(StepperControl), matching: find.byIcon(Icons.add_rounded)).first);
    await tester.pumpAndSettle();
    expect(find.text('450'), findsWidgets);
    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    expect(deps.log.meals.single.items.map((i) => i.servings), [1.5, 1.5]);
  });

  testWidgets('a meal can be renamed', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpPushed(tester, demoReview());
    await tester.tap(find.text('Brown rice').first);
    await tester.pumpAndSettle();
    // The first "Brown rice" is the meal name (fallback); it opens the rename sheet.
    expect(find.text('Meal name'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Rice bowl');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    expect(deps.log.meals.single.title, 'Rice bowl');
  });

  testWidgets('editing an existing meal can delete it after confirming', (tester) async {
    final meal = Meal(
      id: 'm1',
      loggedAt: DateTime.now(),
      type: MealType.lunch,
      source: MealSource.manual,
      items: const [_rice],
    );
    final deps = await TestDeps.create(meals: [meal]);
    await deps.pumpPushed(tester, MealEditorScreen.edit(meal));
    await tester.tap(find.byTooltip('Delete meal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(deps.log.meals, isEmpty);
  });
}
