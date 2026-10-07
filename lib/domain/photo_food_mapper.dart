import 'food_catalog.dart';
import 'models/food_item.dart';

/// One label from the iPhone's on-device image classifier.
typedef VisionLabel = ({String label, double confidence});

/// Turns Apple Vision's photo labels ("rice", "fried_egg"…) into foods from
/// Nutriq's list. The classifier sees *what* is in a photo, not brands or
/// amounts, so every food starts at its usual portion and carries the
/// classifier's confidence (under 0.6 is shown as "check this").
abstract final class PhotoFoodMapper {
  /// Labels below this are too unsure to suggest.
  static const minConfidence = 0.25;
  static const maxFoods = 5;

  /// Vision label → a name in [FoodCatalog]. Labels not listed are ignored.
  static const labelToFood = <String, String>{
    // Rice and grains
    'rice': 'rice',
    'paella': 'fried rice',
    'biryani': 'fried rice',
    'risotto': 'fried rice',
    'oatmeal': 'oatmeal',
    'cereal': 'cereal',
    // Fish and seafood
    'fish': 'fish',
    'tuna': 'tuna',
    'salmon': 'salmon',
    'sardine': 'sardines',
    'mackerel': 'fish',
    'trout': 'fish',
    'seabass': 'fish',
    'snapper': 'fish',
    'swordfish': 'fish',
    'sushi': 'sushi',
    // Eggs
    'egg': 'egg',
    'fried_egg': 'fried egg',
    'scrambled_eggs': 'scrambled egg',
    'omelet': 'omelette',
    // Meat
    'poultry': 'chicken',
    'fried_chicken': 'fried chicken',
    'grilled_chicken': 'grilled chicken',
    'beef': 'beef',
    'steak': 'steak',
    'spareribs': 'ribs',
    'kebab': 'bbq',
    'satay': 'bbq',
    'souvlaki': 'bbq',
    'bacon': 'bacon',
    'ham': 'ham',
    'sausage': 'sausage',
    'hotdog': 'hotdog',
    // Noodles, bread, dishes
    'pasta': 'pasta',
    'spaghetti': 'spaghetti',
    'ramen': 'ramen',
    'bread': 'bread',
    'white_bread': 'white bread',
    'sandwich': 'sandwich',
    'hamburger': 'burger',
    'pizza': 'pizza',
    'fries': 'fries',
    'burrito': 'burrito',
    'taco': 'taco',
    'soup': 'soup',
    'curry': 'curry',
    'dumpling': 'siomai',
    'gyoza': 'siomai',
    'wonton': 'siomai',
    'springroll': 'lumpia',
    'stir_fry': 'chopsuey',
    'pancake': 'pancake',
    'waffle': 'waffle',
    // Vegetables
    'vegetable': 'vegetables',
    'salad': 'salad',
    'coleslaw': 'salad',
    'lettuce': 'salad',
    'broccoli': 'broccoli',
    'carrot': 'carrot',
    'tomato': 'tomato',
    'cucumber': 'cucumber',
    'corn': 'corn',
    'potato': 'potato',
    // Fruit
    'banana': 'banana',
    'mango': 'mango',
    'apple': 'apple',
    'oranges': 'orange',
    'mandarine': 'orange',
    'grape': 'grapes',
    'watermelon': 'watermelon',
    'papaya': 'papaya',
    'pineapple': 'pineapple',
    'strawberry': 'strawberries',
    'avocado': 'avocado',
    // Sweets and snacks
    'cake': 'cake',
    'cake_regular': 'cake',
    'birthday_cake': 'cake',
    'cupcake': 'cake',
    'donut': 'donut',
    'muffin': 'muffin',
    'croissant': 'croissant',
    'pie': 'pie',
    'cookie': 'cookie',
    'chocolate': 'chocolate',
    'ice_cream': 'ice cream',
    'frozen_dessert': 'ice cream',
    'flan': 'leche flan',
    'popcorn': 'popcorn',
    'peanut': 'peanuts',
    'cheese': 'cheese',
    'yogurt': 'yogurt',
    // Drinks
    'coffee': 'coffee',
    'tea_drink': 'tea',
    'juice': 'juice',
    'soda': 'soda',
    'beer': 'beer',
    'milkshake': 'milkshake',
    'smoothie': 'smoothie',
  };

  /// General labels, dropped when one of their specific kinds is also seen.
  static const _general = <String, Set<String>>{
    'egg': {'fried_egg', 'scrambled_eggs', 'omelet'},
    'fish': {'tuna', 'salmon', 'sardine', 'mackerel', 'trout', 'seabass', 'snapper', 'swordfish', 'sushi'},
    'pasta': {'spaghetti', 'ramen'},
    'bread': {'white_bread', 'sandwich', 'croissant', 'muffin', 'donut', 'pancake', 'waffle', 'hamburger'},
    'poultry': {'fried_chicken', 'grilled_chicken'},
    'beef': {'steak'},
    'vegetable': {
      'broccoli',
      'carrot',
      'tomato',
      'cucumber',
      'corn',
      'potato',
      'salad',
      'coleslaw',
      'lettuce',
      'stir_fry',
    },
  };

  static List<FoodItem> foods(List<VisionLabel> labels) {
    final seen = <String, double>{};
    for (final l in labels) {
      if (l.confidence < minConfidence || !labelToFood.containsKey(l.label)) continue;
      if (l.confidence > (seen[l.label] ?? 0)) seen[l.label] = l.confidence;
    }
    seen.removeWhere((label, _) => _general[label]?.any(seen.containsKey) ?? false);

    // Several labels can mean the same food; keep the most confident.
    final byFood = <CatalogFood, double>{};
    for (final MapEntry(key: label, value: confidence) in seen.entries) {
      final food = FoodCatalog.byAlias(labelToFood[label]!)!;
      if (confidence > (byFood[food] ?? 0)) byFood[food] = confidence;
    }
    final ranked = byFood.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final MapEntry(key: food, value: confidence) in ranked.take(maxFoods))
        food.item().copyWith(confidence: (confidence * 100).round() / 100),
    ];
  }
}
