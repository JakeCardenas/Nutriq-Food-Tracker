import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/food_catalog.dart';
import 'package:nutriq/domain/photo_food_mapper.dart';

List<String> _names(List<VisionLabel> labels) => PhotoFoodMapper.foods(labels).map((i) => i.name).toList();

void main() {
  test('every food label maps to a food in Nutriq’s list', () {
    for (final entry in PhotoFoodMapper.labelToFood.entries) {
      expect(FoodCatalog.byAlias(entry.value), isNotNull, reason: '${entry.key} → ${entry.value}');
    }
  });

  test('a plate of tuna and rice', () {
    final items = PhotoFoodMapper.foods([
      (label: 'food', confidence: 0.95),
      (label: 'rice', confidence: 0.82),
      (label: 'grain', confidence: 0.7),
      (label: 'tuna', confidence: 0.41),
      (label: 'fish', confidence: 0.55),
      (label: 'plate', confidence: 0.6),
    ]);
    expect(items.map((i) => i.name), ['White rice, cooked', 'Tuna flakes in oil, canned']);
    expect(items.first.confidence, 0.82);
    expect(items.last.confidence, 0.41);
    expect(items.last.isLowConfidence, isTrue, reason: 'shown with “check this”');
  });

  test('a general label stays when nothing more specific was seen', () {
    expect(_names([(label: 'rice', confidence: 0.8), (label: 'fish', confidence: 0.6)]), [
      'White rice, cooked',
      'Tilapia, fried',
    ]);
  });

  test('a specific label replaces its general one', () {
    expect(_names([(label: 'egg', confidence: 0.7), (label: 'fried_egg', confidence: 0.5)]), ['Egg, fried']);
    expect(_names([(label: 'pasta', confidence: 0.7), (label: 'spaghetti', confidence: 0.6)]), [
      'Spaghetti with meat sauce',
    ]);
  });

  test('weak guesses are left out', () {
    expect(_names([(label: 'rice', confidence: 0.8), (label: 'sushi', confidence: 0.1)]), ['White rice, cooked']);
  });

  test('two labels for the same food give one food', () {
    final items = PhotoFoodMapper.foods([(label: 'cake', confidence: 0.5), (label: 'birthday_cake', confidence: 0.7)]);
    expect(items, hasLength(1));
    expect(items.single.confidence, 0.7);
  });

  test('at most five foods, most confident first', () {
    final names = _names([
      (label: 'rice', confidence: 0.3),
      (label: 'banana', confidence: 0.9),
      (label: 'apple', confidence: 0.8),
      (label: 'coffee', confidence: 0.7),
      (label: 'bread', confidence: 0.6),
      (label: 'egg', confidence: 0.5),
      (label: 'salad', confidence: 0.4),
    ]);
    expect(names, hasLength(5));
    expect(names.first, 'Banana');
    expect(names, isNot(contains('White rice, cooked')));
  });

  test('a photo with no food gives nothing', () {
    expect(
      _names([(label: 'cat', confidence: 0.9), (label: 'sofa', confidence: 0.6), (label: 'food', confidence: 0.3)]),
      isEmpty,
    );
  });
}
