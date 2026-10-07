import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/food_catalog.dart';
import 'package:nutriq/domain/models/scan_draft.dart';
import 'package:nutriq/domain/photo_food_mapper.dart';

/// A label that meets Apple's precision target (only those can be suggested).
VisionLabel _strong(String label, double score) => (label: label, confidence: score, meetsPrecision: true);
VisionLabel _weak(String label, double score) => (label: label, confidence: score, meetsPrecision: false);

List<String> _labels(List<VisionLabel> labels) => PhotoFoodMapper.suggestions(labels).map((s) => s.label).toList();

void main() {
  group('what gets suggested', () {
    test('only labels that meet Apple’s precision target, whatever their raw score', () {
      expect(_labels([_weak('hamburger', 0.95), _strong('banana', 0.4)]), ['Banana']);
    });

    test('broad labels and labels for a different dish are never suggested', () {
      final dropped = [
        'food',
        'meat',
        'poultry',
        'fish',
        'seafood',
        'vegetable',
        'fruit',
        'dessert',
        'drink',
        'paella',
        'biryani',
        'risotto',
        'mackerel',
        'trout',
        'seabass',
        'snapper',
        'swordfish',
        'cereal',
        'coleslaw',
        'lettuce',
        'tableware',
        'plate',
        'bowl',
      ];
      expect(PhotoFoodMapper.suggestions([for (final l in dropped) _strong(l, 0.9)]), isEmpty);
    });

    test('a label that names one food is a direct match', () {
      final s = PhotoFoodMapper.suggestions([_strong('fried_egg', 0.6)]).single;
      expect(s.label, 'Fried egg');
      expect(s.food?.name, 'Egg, fried');
    });

    test('a label that could be several foods becomes a search, not a guess', () {
      final byLabel = {
        for (final s in PhotoFoodMapper.suggestions([
          _strong('tuna', 0.7),
          _strong('rice', 0.6),
          _strong('coffee', 0.5),
        ]))
          s.label: s,
      };
      expect(byLabel.keys, ['Tuna', 'Rice', 'Coffee']);
      for (final s in byLabel.values) {
        expect(s.food, isNull, reason: '${s.label} is ambiguous');
      }
      expect(byLabel['Tuna']!.searchTerm, 'tuna');
      expect(
        FoodCatalog.search('tuna').map((f) => f.name),
        containsAll(['Tuna flakes in oil, canned', 'Tuna in water, canned']),
      );
    });

    test('the general label gives way to a specific one', () {
      expect(_labels([_strong('egg', 0.7), _strong('fried_egg', 0.5)]), ['Fried egg']);
      expect(_labels([_strong('pasta', 0.7), _strong('spaghetti', 0.5)]), ['Spaghetti']);
      expect(_labels([_strong('bread', 0.7), _strong('croissant', 0.6)]), ['Croissant']);
    });

    test('synonyms give one suggestion', () {
      expect(_labels([_strong('cake', 0.5), _strong('birthday_cake', 0.7), _strong('cupcake', 0.4)]), ['Cake']);
      expect(_labels([_strong('oranges', 0.5), _strong('mandarine', 0.6)]), ['Orange']);
      expect(_labels([_strong('dumpling', 0.5), _strong('gyoza', 0.6), _strong('wonton', 0.4)]), ['Dumplings']);
    });

    test('at most three, highest score first — a photo is not an ingredient list', () {
      expect(
        _labels([
          _strong('banana', 0.5),
          _strong('apple', 0.9),
          _strong('mango', 0.7),
          _strong('grape', 0.6),
          _strong('pineapple', 0.3),
        ]),
        ['Apple', 'Mango', 'Grapes'],
      );
    });

    test('nothing food-like gives nothing', () {
      expect(PhotoFoodMapper.suggestions([_strong('cat', 0.9), _strong('sofa', 0.8)]), isEmpty);
    });
  });

  group('the mapping table', () {
    test('every direct match is a food in Nutriq’s list', () {
      for (final MapEntry(key: label, value: m) in PhotoFoodMapper.mappings.entries) {
        if (m.food != null) expect(FoodCatalog.byAlias(m.food!), isNotNull, reason: label);
      }
    });

    test('every search finds at least one food, so “Find” is never empty', () {
      for (final MapEntry(key: label, value: m) in PhotoFoodMapper.mappings.entries) {
        expect(FoodCatalog.search(m.search), isNotEmpty, reason: '$label → “${m.search}”');
      }
    });
  });

  group('saved with the scan draft', () {
    test('suggestions round-trip through JSON', () {
      final draft = ScanDraft(
        id: 'd',
        photoPath: 'p.jpg',
        createdAt: DateTime(2026, 10, 7),
        status: DraftStatus.ready,
        suggestions: PhotoFoodMapper.suggestions([_strong('fried_egg', 0.6), _strong('tuna', 0.5)]),
      );
      final back = ScanDraft.fromJson(draft.toJson());
      expect(back.suggestions.map((s) => s.label), ['Fried egg', 'Tuna']);
      expect(back.suggestions.first.food?.name, 'Egg, fried');
      expect(back.suggestions.last.food, isNull);
      expect(back.suggestions.last.searchTerm, 'tuna');
    });

    test('drafts saved before suggestions existed still load', () {
      final old = ScanDraft(id: 'd', photoPath: 'p.jpg', createdAt: DateTime(2026), status: DraftStatus.ready).toJson()
        ..remove('suggestions');
      expect(ScanDraft.fromJson(old).suggestions, isEmpty);
    });
  });
}
