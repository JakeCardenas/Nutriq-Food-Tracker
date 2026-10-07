import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/food_catalog.dart';

void main() {
  group('data', () {
    test('has a broad list of everyday foods', () {
      expect(FoodCatalog.foods.length, greaterThanOrEqualTo(90));
    });

    test('every food has its default portion and positive weights', () {
      for (final f in FoodCatalog.foods) {
        expect(f.portions.containsKey(f.defaultUnit), isTrue, reason: f.name);
        for (final p in f.portions.values) {
          expect(p.grams, greaterThan(0), reason: f.name);
        }
      }
    });

    test('calories agree with the macros (4/4/9), so no value is a typo', () {
      for (final f in FoodCatalog.foods.where((f) => !f.containsAlcohol)) {
        final fromMacros = f.protein * 4 + f.carbs * 4 + f.fat * 9;
        final tolerance = f.kcal * 0.2 > 15 ? f.kcal * 0.2 : 15;
        expect(
          (fromMacros - f.kcal).abs(),
          lessThanOrEqualTo(tolerance),
          reason: '${f.name}: $fromMacros vs ${f.kcal}',
        );
      }
    });

    test('each alias and brand points to exactly one food', () {
      final seen = <String, String>{};
      for (final f in FoodCatalog.foods) {
        for (final alias in [f.name.toLowerCase(), ...f.aliases, ...f.brands.keys]) {
          expect(alias, alias.trim().toLowerCase(), reason: 'aliases are lowercase: $alias');
          expect(seen[alias], anyOf(isNull, f.name), reason: '“$alias” is used by ${seen[alias]} and ${f.name}');
          seen[alias] = f.name;
        }
      }
    });
  });

  group('portions', () {
    final rice = FoodCatalog.byAlias('rice')!;

    test('a food in its default portion', () {
      final item = rice.item();
      expect(item.name, 'White rice, cooked');
      expect(item.servings, 1);
      expect(item.servingLabel, '1 cup cooked (158 g)');
      expect(item.caloriesPerServing, closeTo(205, 1));
      expect(item.confidence, isNull);
    });

    test('a named unit and a quantity', () {
      final item = FoodCatalog.byAlias('egg')!.item(quantity: 2, unit: 'piece');
      expect(item.servings, 2);
      expect(item.totals.calories, closeTo(180, 10));
    });

    test('grams', () {
      final item = FoodCatalog.byAlias('chicken breast')!.item(quantity: 200, unit: 'g');
      expect(item.servings, 1);
      expect(item.servingLabel, '200 g');
      expect(item.caloriesPerServing, closeTo(330, 1));
    });

    test('a unit the food doesn’t have falls back to its default portion', () {
      final item = rice.item(quantity: 2, unit: 'slice');
      expect(item.servingLabel, '1 cup cooked (158 g)');
      expect(item.servings, 2);
    });

    test('brand names are kept', () {
      final tuna = FoodCatalog.byAlias('century tuna')!;
      expect(tuna.item(brand: 'century tuna').name, 'Century Tuna flakes in oil');
    });
  });

  group('search', () {
    test('finds foods by name, alias and word start, best first', () {
      expect(FoodCatalog.search('rice').first.name, 'White rice, cooked');
      expect(FoodCatalog.search('tuna').map((f) => f.name), contains('Tuna flakes in oil, canned'));
      expect(FoodCatalog.search('pande').map((f) => f.name), contains('Pandesal'));
      expect(FoodCatalog.search('kanin').first.name, 'White rice, cooked');
    });

    test('nothing for an empty query, and a limit', () {
      expect(FoodCatalog.search('  '), isEmpty);
      expect(FoodCatalog.search('e', limit: 3), hasLength(3));
    });
  });
}
