import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/meal_description.dart';
import 'package:nutriq/domain/models/food_item.dart';

List<FoodItem> _items(String text) => MealDescription.parse(text).items;

void main() {
  test('“century tuna and 2 cups of rice”', () {
    final result = MealDescription.parse('century tuna and 2 cups of rice');
    expect(result.unmatched, isEmpty);
    expect(result.items, hasLength(2));

    final tuna = result.items[0];
    expect(tuna.name, 'Century Tuna flakes in oil');
    expect(tuna.servings, 1);
    expect(tuna.servingLabel, contains('can'));
    expect(tuna.totals.calories, inInclusiveRange(200, 320));
    expect(tuna.totals.protein, greaterThan(25));

    final rice = result.items[1];
    expect(rice.name, 'White rice, cooked');
    expect(rice.servings, 2);
    expect(rice.totals.calories, closeTo(410, 10));
  });

  test('a Filipino breakfast with counts', () {
    final items = _items('2 eggs, 1 cup garlic rice and 3 longganisa');
    expect(items.map((i) => i.name), ['Egg, fried', 'Garlic fried rice (sinangag)', 'Longganisa']);
    expect(items.map((i) => i.servings), [2, 1, 3]);
  });

  group('quantities', () {
    double servingsOf(String text) => _items(text).single.servings;

    test('fractions, words and multipliers', () {
      expect(servingsOf('half cup rice'), 0.5);
      expect(servingsOf('a half cup of rice'), 0.5);
      expect(servingsOf('1/2 cup rice'), 0.5);
      expect(servingsOf('½ cup rice'), 0.5);
      expect(servingsOf('1 1/2 cups rice'), 1.5);
      expect(servingsOf('2 and a half cups of rice'), 2.5);
      expect(servingsOf('1.5 cups rice'), 1.5);
      expect(servingsOf('two bananas'), 2);
      expect(servingsOf('a banana'), 1);
      expect(servingsOf('rice x2'), 2);
      expect(servingsOf('3x pandesal'), 3);
      expect(servingsOf('a couple of eggs'), 2);
    });

    test('grams, ml and ounces', () {
      final chicken = _items('200g chicken breast').single;
      expect(chicken.servingLabel, '200 g');
      expect(chicken.totals.calories, closeTo(330, 2));
      expect(_items('250 ml milk').single.servingLabel, '250 ml');
      expect(_items('4 oz salmon').single.servingLabel, '113 g');
    });

    test('units', () {
      final bread = _items('3 slices of bread').single;
      expect(bread.servings, 3);
      expect(bread.servingLabel, contains('slice'));
      expect(_items('tbsp peanut butter').single.servingLabel, contains('tbsp'));
      expect(_items('2 servings of rice').single.servings, 2);
    });
  });

  test('names with “and” or “with” in them stay one food', () {
    expect(_items('coffee with milk'), hasLength(1));
    expect(_items('mac and cheese'), hasLength(1));
    expect(_items('mac and cheese and a banana'), hasLength(2));
  });

  test('typos and plurals', () {
    expect(_items('spagheti').single.name, 'Spaghetti with meat sauce');
    expect(_items('longanisa').single.name, 'Longganisa');
    expect(_items('3 hotdogs').single.servings, 3);
  });

  test('lead-ins and meal words are ignored', () {
    final items = _items('For breakfast I had pandesal and coffee.');
    expect(items.map((i) => i.name), ['Pandesal', 'Coffee, black']);
  });

  test('unknown foods are reported, not guessed', () {
    final result = MealDescription.parse('rice and zorblax');
    expect(result.items.single.name, 'White rice, cooked');
    expect(result.unmatched, ['zorblax']);
  });

  test('empty text gives nothing', () {
    final result = MealDescription.parse('   ');
    expect(result.items, isEmpty);
    expect(result.unmatched, isEmpty);
  });

  test('every item gets its own id', () {
    final items = _items('rice, rice and rice');
    expect(items.map((i) => i.id).toSet(), hasLength(3));
  });

  test('amounts that can’t be right are flagged to check, never logged', () {
    for (final text in [
      '1/0 cup rice',
      '0/0 cup rice',
      '0 cups rice',
      '99999 cups rice',
      '101 eggs',
      '100000 g rice',
    ]) {
      final r = MealDescription.parse(text);
      expect(r.items, isEmpty, reason: text);
      expect(r.unclearAmounts, [text], reason: text);
      expect(r.unmatched, isEmpty, reason: '“$text” is a known food with a wrong amount, not an unknown food');
    }
    final mixed = MealDescription.parse('2 cups rice and 1/0 egg');
    expect(mixed.items.single.name, 'White rice, cooked');
    expect(mixed.unclearAmounts, ['1/0 egg']);
  });

  test('every food it returns can be saved and synced (finite, ≤ 100 servings, ≤ 5,000 kcal each)', () {
    for (final text in ['100 eggs', '2 1/2 cups rice', '½ cup rice', '1500 g rice', '3 cups milk']) {
      for (final item in _items(text)) {
        expect(() => jsonEncode(item.toJson()), returnsNormally, reason: text);
        expect(item.servings, inInclusiveRange(0.01, 100), reason: text);
        expect(item.caloriesPerServing, inInclusiveRange(0, 5000), reason: text);
      }
    }
  });
}
