import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/food_item.dart';
import 'package:nutriq/domain/models/meal.dart';

import '../support/test_app.dart';

/// Buttons that hide their children from VoiceOver must still offer an action to activate them.
void main() {
  testWidgets('the tab bar and logged meals can be activated with VoiceOver / TalkBack', (tester) async {
    final deps = await TestDeps.create(
      meals: [
        Meal(
          id: 'm',
          loggedAt: DateTime.now(),
          type: MealType.lunch,
          source: MealSource.manual,
          items: const [FoodItem(id: 'f', name: 'Rice', caloriesPerServing: 200)],
        ),
      ],
    );
    await deps.pumpApp(tester);

    final semantics = tester.ensureSemantics();
    for (final tab in ['History tab', 'Settings tab']) {
      final node = tester.getSemantics(find.bySemanticsLabel(RegExp('^$tab')));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue, reason: tab);
    }
    final meal = tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Lunch at .*Rice')));
    expect(meal.getSemanticsData().hasAction(SemanticsAction.tap), isTrue, reason: 'opens the meal');
    semantics.dispose();
  });
}
