import 'models/photo_suggestion.dart';

/// One label from the iPhone's general-purpose image classifier (Apple Vision).
///
/// [confidence] is Vision's raw score for that label. It is not a calibrated
/// probability that the food is present, so Nutriq only uses it to order
/// suggestions. [meetsPrecision] says whether the score clears the precision
/// target on Apple's own per-label precision/recall curve (see
/// `FoodVisionPlugin` in ios/Runner/AppDelegate.swift); only those labels can
/// become suggestions.
typedef VisionLabel = ({String label, double confidence, bool meetsPrecision});

/// How a Vision label relates to Nutriq's food list.
typedef PhotoMapping = ({String label, String search, String? food});

/// Turns Vision labels into a few *suggestions* — never into logged foods or
/// portions. A label maps straight to a food only when it names exactly that
/// food ("banana", "fried_egg"); a label that could be several foods ("rice",
/// "tuna", "coffee") becomes a search; broad labels ("food", "fish", "meat")
/// and labels for different dishes ("paella") are ignored.
abstract final class PhotoFoodMapper {
  /// More than this turns whole-image labels into a fake ingredient list.
  static const maxSuggestions = 3;

  static const mappings = <String, PhotoMapping>{
    // ── Names one food in Nutriq's list ────────────────────────────────────
    'banana': (label: 'Banana', search: 'banana', food: 'Banana'),
    'apple': (label: 'Apple', search: 'apple', food: 'Apple'),
    'mango': (label: 'Mango', search: 'mango', food: 'Mango, ripe'),
    'oranges': (label: 'Orange', search: 'orange', food: 'Orange'),
    'mandarine': (label: 'Orange', search: 'orange', food: 'Orange'),
    'grape': (label: 'Grapes', search: 'grape', food: 'Grapes'),
    'watermelon': (label: 'Watermelon', search: 'watermelon', food: 'Watermelon'),
    'papaya': (label: 'Papaya', search: 'papaya', food: 'Papaya'),
    'pineapple': (label: 'Pineapple', search: 'pineapple', food: 'Pineapple'),
    'strawberry': (label: 'Strawberries', search: 'strawberr', food: 'Strawberries'),
    'avocado': (label: 'Avocado', search: 'avocado', food: 'Avocado'),
    'broccoli': (label: 'Broccoli', search: 'broccoli', food: 'Broccoli, cooked'),
    'carrot': (label: 'Carrot', search: 'carrot', food: 'Carrot'),
    'tomato': (label: 'Tomato', search: 'tomato', food: 'Tomato'),
    'cucumber': (label: 'Cucumber', search: 'cucumber', food: 'Cucumber'),
    'fried_egg': (label: 'Fried egg', search: 'egg', food: 'Egg, fried'),
    'scrambled_eggs': (label: 'Scrambled eggs', search: 'scrambled', food: 'Scrambled eggs'),
    'hamburger': (label: 'Hamburger', search: 'burger', food: 'Hamburger'),
    'pizza': (label: 'Pizza', search: 'pizza', food: 'Pizza'),
    'fries': (label: 'French fries', search: 'fries', food: 'French fries'),
    'hotdog': (label: 'Hotdog', search: 'hotdog', food: 'Hotdog'),
    'bacon': (label: 'Bacon', search: 'bacon', food: 'Bacon'),
    'ham': (label: 'Ham', search: 'ham', food: 'Ham'),
    'fried_chicken': (label: 'Fried chicken', search: 'fried chicken', food: 'Fried chicken'),
    'steak': (label: 'Steak', search: 'steak', food: 'Beef steak'),
    'spareribs': (label: 'Ribs', search: 'ribs', food: 'Pork ribs'),
    'burrito': (label: 'Burrito', search: 'burrito', food: 'Burrito'),
    'taco': (label: 'Taco', search: 'taco', food: 'Taco'),
    'sushi': (label: 'Sushi', search: 'sushi', food: 'Sushi'),
    'salmon': (label: 'Salmon', search: 'salmon', food: 'Salmon, cooked'),
    'oatmeal': (label: 'Oatmeal', search: 'oat', food: 'Oatmeal, cooked'),
    'white_bread': (label: 'White bread', search: 'bread', food: 'White bread'),
    'pancake': (label: 'Pancake', search: 'pancake', food: 'Pancake'),
    'waffle': (label: 'Waffle', search: 'waffle', food: 'Waffle'),
    'donut': (label: 'Donut', search: 'donut', food: 'Donut'),
    'muffin': (label: 'Muffin', search: 'muffin', food: 'Muffin'),
    'croissant': (label: 'Croissant', search: 'croissant', food: 'Croissant'),
    'cake': (label: 'Cake', search: 'cake', food: 'Cake'),
    'cake_regular': (label: 'Cake', search: 'cake', food: 'Cake'),
    'birthday_cake': (label: 'Cake', search: 'cake', food: 'Cake'),
    'cupcake': (label: 'Cake', search: 'cake', food: 'Cake'),
    'cookie': (label: 'Cookie', search: 'cookie', food: 'Cookies'),
    'ice_cream': (label: 'Ice cream', search: 'ice cream', food: 'Ice cream'),
    'flan': (label: 'Leche flan', search: 'flan', food: 'Leche flan'),
    'popcorn': (label: 'Popcorn', search: 'popcorn', food: 'Popcorn'),
    'peanut': (label: 'Peanuts', search: 'peanut', food: 'Peanuts'),
    'beer': (label: 'Beer', search: 'beer', food: 'Beer'),
    'milkshake': (label: 'Milkshake', search: 'milkshake', food: 'Milkshake'),
    'smoothie': (label: 'Smoothie', search: 'smoothie', food: 'Fruit shake / smoothie'),

    // ── Could be several foods: the person picks from a search ─────────────
    'rice': (label: 'Rice', search: 'rice', food: null),
    'tuna': (label: 'Tuna', search: 'tuna', food: null),
    'sardine': (label: 'Sardines', search: 'sardine', food: null),
    'egg': (label: 'Egg', search: 'egg', food: null),
    'omelet': (label: 'Omelette', search: 'omelette', food: null),
    'grilled_chicken': (label: 'Grilled chicken', search: 'chicken', food: null),
    'spaghetti': (label: 'Spaghetti', search: 'spaghetti', food: null),
    'pasta': (label: 'Pasta', search: 'pasta', food: null),
    'ramen': (label: 'Noodles', search: 'noodle', food: null),
    'bread': (label: 'Bread', search: 'bread', food: null),
    'sandwich': (label: 'Sandwich', search: 'sandwich', food: null),
    'soup': (label: 'Soup', search: 'soup', food: null),
    'curry': (label: 'Curry', search: 'curry', food: null),
    'dumpling': (label: 'Dumplings', search: 'dumpling', food: null),
    'gyoza': (label: 'Dumplings', search: 'dumpling', food: null),
    'wonton': (label: 'Dumplings', search: 'dumpling', food: null),
    'springroll': (label: 'Spring roll', search: 'spring roll', food: null),
    'stir_fry': (label: 'Stir-fry', search: 'stir', food: null),
    'salad': (label: 'Salad', search: 'salad', food: null),
    'potato': (label: 'Potato', search: 'potato', food: null),
    'corn': (label: 'Corn', search: 'corn', food: null),
    'sausage': (label: 'Sausage', search: 'sausage', food: null),
    'kebab': (label: 'Grilled skewer', search: 'barbecue', food: null),
    'satay': (label: 'Grilled skewer', search: 'barbecue', food: null),
    'souvlaki': (label: 'Grilled skewer', search: 'barbecue', food: null),
    'pie': (label: 'Pie', search: 'pie', food: null),
    'chocolate': (label: 'Chocolate', search: 'chocolate', food: null),
    'frozen_dessert': (label: 'Frozen dessert', search: 'ice cream', food: null),
    'yogurt': (label: 'Yogurt', search: 'yogurt', food: null),
    'cheese': (label: 'Cheese', search: 'cheese', food: null),
    'coffee': (label: 'Coffee', search: 'coffee', food: null),
    'tea_drink': (label: 'Tea', search: 'tea', food: null),
    'juice': (label: 'Juice', search: 'juice', food: null),
    'soda': (label: 'Soft drink', search: 'soda', food: null),
  };

  /// A general label is dropped when one of its specific kinds is also seen.
  static const _general = <String, Set<String>>{
    'egg': {'fried_egg', 'scrambled_eggs', 'omelet'},
    'pasta': {'spaghetti', 'ramen'},
    'bread': {'white_bread', 'sandwich', 'croissant', 'muffin', 'donut', 'pancake', 'waffle', 'hamburger'},
  };

  static List<PhotoSuggestion> suggestions(List<VisionLabel> labels) {
    final scores = <String, double>{};
    for (final l in labels) {
      if (!l.meetsPrecision || !mappings.containsKey(l.label)) continue;
      if (l.confidence > (scores[l.label] ?? -1)) scores[l.label] = l.confidence;
    }
    scores.removeWhere((label, _) => _general[label]?.any(scores.containsKey) ?? false);

    // Synonyms ("cake", "cupcake") collapse into one suggestion, keeping the best score.
    final best = <String, ({PhotoMapping mapping, double score})>{};
    for (final MapEntry(key: label, value: score) in scores.entries) {
      final mapping = mappings[label]!;
      final key = mapping.food ?? 'search:${mapping.search}';
      if (score > (best[key]?.score ?? -1)) best[key] = (mapping: mapping, score: score);
    }
    final ranked = best.values.toList()..sort((a, b) => b.score.compareTo(a.score));
    return [
      for (final r in ranked.take(maxSuggestions))
        PhotoSuggestion(label: r.mapping.label, searchTerm: r.mapping.search, foodName: r.mapping.food),
    ];
  }
}
