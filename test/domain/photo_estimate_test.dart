import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/meal_description.dart';
import 'package:nutriq/domain/models/photo_estimate.dart';
import 'package:nutriq/domain/models/scan_draft.dart';
import 'package:nutriq/domain/photo_estimate_resolver.dart';

Map<String, Object?> _usda({
  int id = 171477,
  String description = 'Chicken, broilers or fryers, fried',
  num kcal = 280,
  num protein = 25,
}) => {
  'fdcId': id,
  'description': description,
  'dataType': 'SR Legacy',
  'kcal': kcal,
  'protein': protein,
  'carbs': 9.4,
  'fat': 15.8,
};

Map<String, Object?> _food(
  String name, {
  String? localName,
  String visibility = 'visible',
  Map<String, Object?>? grams,
  Map<String, Object?>? fdc,
  List<Object?>? options,
  List<Object?>? alternatives,
}) => {
  'name': name,
  'localName': localName,
  'visibility': visibility,
  'grams': grams,
  'fdc': fdc,
  'fdcOptions': ?options,
  'alternatives': ?alternatives,
};

final _breast = _usda(
  id: 171477,
  description: 'Chicken, broilers or fryers, breast, meat only, fried',
  kcal: 187,
  protein: 33.4,
);
final _wing = _usda(
  id: 171482,
  description: 'Chicken, broilers or fryers, wing, meat and skin, fried',
  kcal: 321,
  protein: 26.1,
);

PhotoEstimate _resolve(List<Map<String, Object?>> foods, {String? dish = 'Chicken with rice'}) =>
    PhotoEstimateResolver.fromResponse({
      'isFood': true,
      'dish': dish,
      'dishAlternatives': ['Chicken inasal'],
      'foods': foods,
      'uncertainties': ['Cooking oil isn’t visible'],
      'remaining': 8,
      'nutritionLookup': 'fdc',
    })!;

void main() {
  group('matching: Nutriq’s food list first, then USDA, else nothing', () {
    test('a local name that is in the food list wins', () {
      final f = _resolve([_food('white rice, cooked', localName: 'kanin', fdc: _usda())]).foods.single;
      expect(f.source, NutritionSource.catalog);
      expect(f.matchName, 'White rice, cooked');
      expect(f.kcal100, 130);
    });

    test('a generic name equal to a food-list name matches', () {
      final f = _resolve([_food('Egg, fried')]).foods.single;
      expect(f.source, NutritionSource.catalog);
      expect(f.matchName, 'Egg, fried');
    });

    test('only whole names match — “chicken, fried” is not chicken breast', () {
      final f = _resolve([_food('chicken, fried', fdc: _usda())]).foods.single;
      expect(f.source, NutritionSource.usda);
      expect(f.matchName, 'Chicken, broilers or fryers, fried');
      expect(f.dataType, 'SR Legacy', reason: 'shown with the match');
      expect(f.fdcId, 171477);
      expect(f.kcal100, 280);
    });

    test('several possible USDA entries: none is used until the person picks one', () {
      final f = _resolve([
        _food(
          'battered chicken',
          grams: {'low': 120, 'high': 160, 'note': ''},
          options: [_breast, _wing, _usda(kcal: -1), 'junk'],
        ),
      ]).foods.single;
      expect(f.source, NutritionSource.none);
      expect(f.hasNutrition, isFalse, reason: 'no macros from a food that may be the wrong one');
      expect(f.totalsFor(140), isNull);
      expect(f.usdaOptions.map((o) => o.description), [
        'Chicken, broilers or fryers, breast, meat only, fried',
        'Chicken, broilers or fryers, wing, meat and skin, fried',
      ]);
      expect(f.usdaOptions.first.dataType, 'SR Legacy');

      final wing = f.withUsda(f.usdaOptions[1]);
      expect(wing.source, NutritionSource.usda);
      expect(wing.pickedByPerson, isTrue);
      expect(wing.matchName, 'Chicken, broilers or fryers, wing, meat and skin, fried');
      expect(wing.fdcId, 171482);
      expect(wing.kcal100, 321);
      expect(wing.suggestedGrams, 140, reason: 'the amount is still the photo’s estimate');
      expect(wing.usdaOptions, hasLength(2), reason: 'the person can change their pick');
      expect(wing.toItem(100).caloriesPerServing, 321);
    });

    test('a clear USDA match comes without options; at most 4 options are kept', () {
      expect(
        _resolve([
          _food('chicken, fried', fdc: _usda(), options: [_wing]),
        ]).foods.single.usdaOptions,
        isEmpty,
      );
      final many = _resolve([
        _food('battered chicken', options: [for (var i = 1; i <= 6; i++) _usda(id: i)]),
      ]).foods.single;
      expect(many.usdaOptions, hasLength(4));
    });

    test('no trusted match → no nutrition, never a guess', () {
      final f = _resolve([_food('zorblax stew', fdc: null)]).foods.single;
      expect(f.source, NutritionSource.none);
      expect(f.hasNutrition, isFalse);
      expect(f.totalsFor(200), isNull);
    });

    test('broken USDA values are ignored', () {
      for (final bad in [
        _usda(kcal: -5),
        _usda(protein: 500),
        {'fdcId': 'x', 'kcal': 100, 'protein': 5},
      ]) {
        expect(_resolve([_food('mystery', fdc: bad)]).foods.single.source, NutritionSource.none);
      }
    });
  });

  group('amounts', () {
    test('the photo’s range gives the starting amount', () {
      final f = _resolve([
        _food('rice', localName: 'kanin', grams: {'low': 250, 'high': 330, 'note': 'about 2 cups'}),
      ]).foods.single;
      expect(f.gramsFromPhoto, isTrue);
      expect(f.photoLow, 250);
      expect(f.photoHigh, 330);
      expect(f.portionNote, 'about 2 cups');
      expect(f.suggestedGrams, 290);
    });

    test('without one, a food-list match starts at its typical serving (not from the photo)', () {
      final f = _resolve([_food('rice', localName: 'kanin')]).foods.single;
      expect(f.gramsFromPhoto, isFalse);
      expect(f.suggestedGrams, 158);
    });

    test('a USDA match without a photo amount has no starting amount — the person chooses', () {
      expect(_resolve([_food('chicken, fried', fdc: _usda())]).foods.single.suggestedGrams, isNull);
    });
  });

  group('nutrition is computed from per-100 g data × grams', () {
    test('totals for an amount', () {
      final rice = _resolve([_food('rice', localName: 'kanin')]).foods.single;
      final t = rice.totalsFor(200)!;
      expect(t.calories, 260);
      expect(t.protein, closeTo(5.4, 0.001));
    });

    test('a meal total adds only foods with nutrition and an amount', () {
      final e = _resolve([_food('rice', localName: 'kanin'), _food('chicken, fried', fdc: _usda()), _food('zorblax')]);
      final total = PhotoEstimate.totalFor([
        (e.foods[0], 200.0),
        (e.foods[1], 100.0),
        (e.foods[2], 150.0),
        (e.foods[1], null),
      ]);
      expect(total.calories, 260 + 280);
      expect(total.protein, closeTo(5.4 + 25, 0.001));
    });

    test('a very large amount becomes equal servings, each within what can sync (≤ 5,000 kcal)', () {
      final oil = _resolve([_food('cooking oil')]).foods.single;
      final item = oil.toItem(2000);
      expect(item.servings, 4);
      expect(item.servingLabel, '500 g');
      expect(item.caloriesPerServing, lessThanOrEqualTo(5000));
      expect(item.totals.calories, closeTo(oil.kcal100! * 20, 1), reason: 'the total is unchanged');
      expect(_resolve([_food('rice', localName: 'kanin')]).foods.single.toItem(300).servings, 1);
    });

    test('a confirmed food becomes an ingredient with the chosen grams', () {
      final item = _resolve([_food('chicken, fried', fdc: _usda())]).foods.single.toItem(150);
      expect(item.name, 'Chicken, fried');
      expect(item.servings, 1);
      expect(item.servingLabel, '150 g');
      expect(item.caloriesPerServing, 420);
      expect(item.proteinPerServing, 37.5);
    });
  });

  test('dish, alternatives, uncertainties and inferred foods are kept', () {
    final e = _resolve([_food('cooking oil', visibility: 'inferred')]);
    expect(e.dish, 'Chicken with rice');
    expect(e.alternatives, ['Chicken inasal']);
    expect(e.uncertainties, ['Cooking oil isn’t visible']);
    expect(e.foods.single.inferred, isTrue);
    expect(e.nutritionLookup, 'fdc');
  });

  test('a photo without food gives no foods; junk gives no estimate', () {
    expect(
      PhotoEstimateResolver.fromResponse({
        'isFood': false,
        'foods': [_food('cat')],
      })!.foods,
      isEmpty,
    );
    expect(PhotoEstimateResolver.fromResponse({'foods': 'nope'}), isNull);
  });

  test('round-trips through JSON, including inside a scan draft', () {
    final e = _resolve([
      _food('rice', localName: 'kanin', grams: {'low': 250, 'high': 330, 'note': ''}),
      _food('chicken, fried', fdc: _usda()),
      _food('zorblax'),
      _food('battered chicken', options: [_breast, _wing]),
    ]);
    final draft = ScanDraft(
      id: 'd',
      photoPath: 'p.jpg',
      createdAt: DateTime(2026, 10, 7),
      status: DraftStatus.ready,
      estimate: e,
      notice: 'note',
    );
    final back = ScanDraft.fromJson(draft.toJson());
    expect(back.notice, 'note');
    expect(back.estimate!.toJson(), e.toJson());
    expect(back.estimate!.foods[1].source, NutritionSource.usda);
    expect(back.estimate!.foods[0].suggestedGrams, 290);
    expect(back.estimate!.foods[1].dataType, 'SR Legacy');
    expect(back.estimate!.foods[3].usdaOptions.map((o) => o.fdcId), [171477, 171482]);
    final picked = e.foods[3].withUsda(e.foods[3].usdaOptions.first);
    expect(EstimatedFood.fromJson(picked.toJson()).toJson(), picked.toJson());

    final old = draft.toJson()
      ..remove('estimate')
      ..remove('notice');
    expect(ScanDraft.fromJson(old).estimate, isNull);
  });

  group('alternatives when the photo is ambiguous', () {
    test('kept from the analysis: cleaned, no repeats, not the food itself, at most 2', () {
      final f = _resolve([
        _food('chicken adobo', alternatives: ['Pork adobo', 'chicken adobo', 7, '  ', 'pork adobo', 'Humba', 'Pares']),
      ]).foods.single;
      expect(f.alternatives, ['Pork adobo', 'Humba']);
      expect(_resolve([_food('rice', localName: 'kanin')]).foods.single.alternatives, isEmpty);
    });

    test('switching to an alternative re-matches it; the photo’s amount stays', () {
      final f = _resolve([
        _food(
          'chicken adobo',
          grams: {'low': 150, 'high': 210, 'note': 'one bowl'},
          alternatives: ['pork adobo', 'humba'],
        ),
      ]).foods.single;
      expect(f.matchName, 'Chicken adobo');

      final pork = PhotoEstimateResolver.alternative(f, 'pork adobo');
      expect(pork.name, 'pork adobo');
      expect(pork.source, NutritionSource.catalog);
      expect(pork.matchName, 'Pork adobo');
      expect(pork.suggestedGrams, 180, reason: 'same food on the plate, same estimated amount');
      expect(pork.portionNote, 'one bowl');

      final humba = PhotoEstimateResolver.alternative(f, 'humba');
      expect(humba.source, NutritionSource.none, reason: 'not in the food list → no nutrition, never a guess');
      expect(humba.hasNutrition, isFalse);
    });

    test('alternatives survive a saved draft; older drafts load without them', () {
      final e = _resolve([
        _food('chicken adobo', alternatives: ['pork adobo']),
      ]);
      expect(PhotoEstimate.fromJson(e.toJson()).foods.single.alternatives, ['pork adobo']);
      final old = e.foods.single.toJson()..remove('alternatives');
      expect(EstimatedFood.fromJson(old).alternatives, isEmpty);
    });
  });

  group('food-list matching for photo labels', () {
    test('generic words never become one specific food', () {
      for (final generic in [
        'chicken',
        'Fish',
        'egg',
        'itlog',
        'rice',
        'pork',
        'beef',
        'tuna',
        'vegetables',
        'gulay',
        'soup',
        'pancit',
        'spaghetti',
        'juice',
        'coffee',
        'tea',
        'bbq',
        'sausage',
        'bread',
        'salad',
        'curry',
        'dumpling',
        'porridge',
        'cereal',
        'noodle soup',
      ]) {
        expect(MealDescription.exactMatch(generic), isNull, reason: generic);
      }
      expect(_resolve([_food('chicken')]).foods.single.source, NutritionSource.none);
    });

    test('specific names, local names and common Filipino spellings still match', () {
      const cases = {
        'kanin': 'White rice, cooked',
        'puting kanin': 'White rice, cooked',
        'white rice': 'White rice, cooked',
        'fried egg': 'Egg, fried',
        'pritong itlog': 'Egg, fried',
        'pritong manok': 'Fried chicken',
        'pritong tilapia': 'Tilapia, fried',
        'pritong bangus': 'Milkfish (bangus), fried',
        'tinolang manok': 'Chicken tinola',
        'nilagang baka': 'Bulalo (beef soup)',
        'tortang itlog': 'Scrambled eggs',
        'sinangag na kanin': 'Garlic fried rice (sinangag)',
        'adobong manok': 'Chicken adobo',
        'sinigang na baboy': 'Pork sinigang',
        'longanisa': 'Longganisa',
        'spaghetti with meat sauce': 'Spaghetti with meat sauce',
      };
      for (final MapEntry(key: label, value: name) in cases.entries) {
        expect(MealDescription.exactMatch(label)?.name, name, reason: label);
      }
    });

    test('typed descriptions still understand everyday words', () {
      final names = MealDescription.parse('chicken and rice').items.map((i) => i.name);
      expect(names, ['Chicken breast, cooked', 'White rice, cooked']);
    });
  });

  test('exact food-list matching is available to other features', () {
    expect(MealDescription.exactMatch('sinangag')?.name, 'Garlic fried rice (sinangag)');
    expect(MealDescription.exactMatch('chicken, fried'), isNull);
    expect(MealDescription.exactMatch('Spagheti'), isNull, reason: 'no typo matching here');
  });
}
