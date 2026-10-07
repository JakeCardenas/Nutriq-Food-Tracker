import 'dart:math' as math;

import 'food_catalog.dart';
import 'models/food_item.dart';

/// Foods read from a description, plus the parts Nutriq didn't recognise.
class MealParse {
  const MealParse({required this.items, required this.unmatched, this.unclearAmounts = const []});
  final List<FoodItem> items;
  final List<String> unmatched;

  /// Known foods whose amount can't be right ("1/0 cup rice", "99999 cups") — left out for the person to check.
  final List<String> unclearAmounts;
}

/// Turns "century tuna and 2 cups of rice" into foods from [FoodCatalog] —
/// on the device, no AI. Unknown parts are returned, never guessed.
abstract final class MealDescription {
  static MealParse parse(String text) {
    var t = _normalize(text);
    // "2 and a half cups" before "and" splits it.
    t = t.replaceAllMapped(RegExp(r'\b(\d+) and a half\b'), (m) => '${m[1]}.5');
    // Names that contain a separator word ("coffee with milk") stay whole.
    for (final c in _compounds) {
      t = t.replaceAll(RegExp('\\b${RegExp.escape(c)}\\b'), c.replaceAll(' ', '_'));
    }

    final items = <FoodItem>[];
    final unmatched = <String>[];
    final unclear = <String>[];
    for (final raw in t.split(RegExp(r'\s*(?:[,;+\n]|\band\b|\bwith\b|\bplus\b|\bthen\b|\balso\b)\s*'))) {
      final chunk = raw.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (chunk.isEmpty || _filler.contains(chunk)) continue;
      final amount = _amount(chunk);
      final match = _match(amount.food);
      if (match == null) {
        unmatched.add(chunk);
        continue;
      }
      final item = match.food.item(quantity: amount.quantity, unit: amount.unit, brand: match.brand);
      if (_plausible(item)) {
        items.add(item);
      } else {
        unclear.add(chunk);
      }
    }
    return MealParse(items: items, unmatched: unmatched, unclearAmounts: unclear);
  }

  /// Within what can be saved and synced (the cloud accepts 0–100 servings and up to 5,000 kcal per
  /// serving) — so "1/0 cup" (infinite), "0/0" (not a number), "0 cups" or "99999 cups" never reach a meal.
  static bool _plausible(FoodItem i) {
    final values = [i.servings, i.caloriesPerServing, i.proteinPerServing, i.carbsPerServing, i.fatPerServing];
    return values.every((v) => v.isFinite && v >= 0) &&
        i.servings > 0 &&
        i.servings <= 100 &&
        i.caloriesPerServing <= 5000;
  }

  // ── Text clean-up ─────────────────────────────────────────────────────────

  static String _normalize(String text) {
    var t = ' ${text.toLowerCase()} '
        .replaceAll(RegExp('[’‘`]'), "'")
        .replaceAll('&', ' and ')
        .replaceAllMapped(RegExp(r'(\d)?\s*([½¼¾⅓])'), (m) {
          final frac = const {'½': '1/2', '¼': '1/4', '¾': '3/4', '⅓': '1/3'}[m[2]]!;
          return m[1] == null ? ' $frac' : '${m[1]} $frac';
        })
        .replaceAll(RegExp(r'\b3\s*-?\s*in\s*-?\s*1\b'), 'threeinone')
        // Full stops end sentences unless they're decimal points.
        .replaceAll(RegExp(r'(?<!\d)\.|\.(?!\d)'), ' ')
        .replaceAll(RegExp(r"[^a-z0-9/.,;+\n' _-]"), ' ');
    for (final lead in _leadIns) {
      t = t.replaceAll(lead, ' ');
    }
    return t.replaceAll(RegExp(r'[ \t]+'), ' ');
  }

  static final _leadIns = [
    RegExp(r"\b(?:for|at|during) (?:breakfast|lunch|dinner|supper|merienda|snack|brunch)\b"),
    RegExp(
      r"\b(?:my |our )?(?:breakfast|lunch|dinner|supper|merienda|snack|brunch|meal)(?: today| earlier)? (?:was|is)\b",
    ),
    RegExp(r"\b(?:i|we) (?:just |also )?(?:had|ate|have|eat|drank|got)\b"),
    RegExp(r"\b(?:i'm|im|i am) (?:having|eating|drinking)\b"),
    RegExp(r"\b(?:today|earlier|this morning|this afternoon|tonight|yesterday|just now)\b"),
    RegExp(r'^\s*(?:breakfast|lunch|dinner|snack|merienda)\s*:'),
  ];

  static const _filler = {'some', 'a', 'an', 'the', 'had', 'ate', 'also', 'of', 'too'};

  /// Catalog names containing a separator word, longest first.
  static final List<String> _compounds = [
    for (final f in FoodCatalog.foods)
      for (final a in [...f.aliases, ...f.brands.keys])
        if (RegExp(r'\b(?:and|with|plus|then)\b').hasMatch(a)) _normalizeAlias(a),
  ]..sort((a, b) => b.length - a.length);

  // ── Amounts ───────────────────────────────────────────────────────────────

  static const _numberWords = {
    'a couple of': 2.0,
    'a couple': 2.0,
    'couple of': 2.0,
    'couple': 2.0,
    'a few': 3.0,
    'few': 3.0,
    'a dozen': 12.0,
    'dozen': 12.0,
    'a half': 0.5,
    'half a': 0.5,
    'half an': 0.5,
    'half': 0.5,
    'one': 1.0,
    'two': 2.0,
    'three': 3.0,
    'four': 4.0,
    'five': 5.0,
    'six': 6.0,
    'seven': 7.0,
    'eight': 8.0,
    'nine': 9.0,
    'ten': 10.0,
    'an': 1.0,
    'a': 1.0,
    'some': 1.0,
  };

  /// Spoken unit → (catalog unit, grams-or-ml per unit for weight units).
  static const _units = <String, (String, double?)>{
    'cups': ('cup', null),
    'cup': ('cup', null),
    'c': ('cup', null),
    'mugs': ('cup', null),
    'mug': ('cup', null),
    'cans': ('can', null),
    'can': ('can', null),
    'tins': ('can', null),
    'tin': ('can', null),
    'pieces': ('piece', null),
    'piece': ('piece', null),
    'pcs': ('piece', null),
    'pc': ('piece', null),
    'fillets': ('piece', null),
    'fillet': ('piece', null),
    'ears': ('piece', null),
    'ear': ('piece', null),
    'slices': ('slice', null),
    'slice': ('slice', null),
    'wedges': ('slice', null),
    'wedge': ('slice', null),
    'bowls': ('bowl', null),
    'bowl': ('bowl', null),
    'plates': ('plate', null),
    'plate': ('plate', null),
    'servings': ('serving', null),
    'serving': ('serving', null),
    'serves': ('serving', null),
    'tablespoons': ('tbsp', null),
    'tablespoon': ('tbsp', null),
    'tbsps': ('tbsp', null),
    'tbsp': ('tbsp', null),
    'tbs': ('tbsp', null),
    'teaspoons': ('tsp', null),
    'teaspoon': ('tsp', null),
    'tsps': ('tsp', null),
    'tsp': ('tsp', null),
    'glasses': ('glass', null),
    'glass': ('glass', null),
    'packs': ('pack', null),
    'pack': ('pack', null),
    'packets': ('pack', null),
    'packet': ('pack', null),
    'sachets': ('sachet', null),
    'sachet': ('sachet', null),
    'scoops': ('scoop', null),
    'scoop': ('scoop', null),
    'sticks': ('stick', null),
    'stick': ('stick', null),
    'handfuls': ('handful', null),
    'handful': ('handful', null),
    'grams': ('g', 1),
    'gram': ('g', 1),
    'gr': ('g', 1),
    'g': ('g', 1),
    'kilos': ('g', 1000),
    'kilo': ('g', 1000),
    'kg': ('g', 1000),
    'ounces': ('g', 28.35),
    'ounce': ('g', 28.35),
    'oz': ('g', 28.35),
    'ml': ('ml', 1),
    'liters': ('ml', 1000),
    'liter': ('ml', 1000),
    'litres': ('ml', 1000),
    'litre': ('ml', 1000),
    'l': ('ml', 1000),
  };

  static final _unitPattern = (_units.keys.toList()..sort((a, b) => b.length - a.length)).join('|');
  static final _number = r'(\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)';

  static ({double quantity, String? unit, String food}) _amount(String chunk) {
    var rest = chunk;
    double? quantity;

    // "3x pandesal" / "pandesal x3" / "pandesal (2)"
    final leadingTimes = RegExp('^$_number\\s*x\\s+').firstMatch(rest);
    final trailingTimes = RegExp('\\s+(?:x\\s*$_number|$_number\\s*x|\\($_number\\))\$').firstMatch(rest);
    if (leadingTimes != null) {
      quantity = _toNumber(leadingTimes[1]!);
      rest = rest.substring(leadingTimes.end);
    } else if (trailingTimes != null) {
      quantity = _toNumber((trailingTimes[1] ?? trailingTimes[2] ?? trailingTimes[3])!);
      rest = rest.substring(0, trailingTimes.start);
    }

    if (quantity == null) {
      final digits = RegExp('^$_number(?=\\s|[a-z]|\$)\\s*').firstMatch(rest);
      if (digits != null) {
        quantity = _toNumber(digits[1]!);
        rest = rest.substring(digits.end);
      } else {
        for (final entry in _numberWords.entries) {
          final word = RegExp('^${entry.key}\\b\\s*').firstMatch(rest);
          if (word != null) {
            quantity = entry.value;
            rest = rest.substring(word.end);
            break;
          }
        }
      }
    }

    // "rice 2 cups"
    if (quantity == null) {
      final trailing = RegExp('\\s$_number\\s*($_unitPattern)?\$').firstMatch(rest);
      if (trailing != null) {
        quantity = _toNumber(trailing[1]!);
        rest = '${trailing[2] ?? ''} ${rest.substring(0, trailing.start)}'.trim();
      }
    }

    rest = rest.replaceFirst(RegExp(r'^(?:small|medium|large|big|regular|extra large|xl)\s+'), '');
    String? unit;
    final unitMatch = RegExp('^($_unitPattern)\\b\\.?\\s*(?:of\\s+)?').firstMatch(rest);
    if (unitMatch != null && unitMatch.end < rest.length) {
      final (name, factor) = _units[unitMatch[1]]!;
      unit = name;
      quantity = (quantity ?? 1) * (factor ?? 1);
      if (factor != null && factor != 1) quantity = quantity.roundToDouble();
      rest = rest.substring(unitMatch.end);
    }
    rest = rest
        .replaceFirst(RegExp(r'^(?:of|the|some|my|half)\s+'), '')
        .replaceAll(RegExp(r'\b(?:small|medium|large|big|regular)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return (quantity: quantity ?? 1, unit: unit, food: rest);
  }

  static double _toNumber(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    var total = 0.0;
    for (final p in parts) {
      final frac = p.split('/');
      total += frac.length == 2 ? double.parse(frac[0]) / double.parse(frac[1]) : double.parse(p);
    }
    return total;
  }

  // ── Matching ──────────────────────────────────────────────────────────────

  /// (normalized alias, food, brand or null), longest alias first.
  static final List<(String, CatalogFood, String?)> _index = [
    for (final f in FoodCatalog.foods) ...[
      (_normalizeAlias(f.name), f, null),
      for (final a in f.aliases) (_normalizeAlias(a), f, null),
      for (final b in f.brands.keys) (_normalizeAlias(b), f, b),
    ],
  ]..sort((a, b) => b.$1.length - a.$1.length);

  static String _normalizeAlias(String a) => a
      .toLowerCase()
      .replaceAll(RegExp(r'\b3\s*-?\s*in\s*-?\s*1\b'), 'threeinone')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// The food whose name, alias or brand is exactly [text] (ignoring case,
  /// punctuation and plurals) — no partial or typo matches, and none of the
  /// [_genericAliases]. For suggestions that come from elsewhere (e.g. a
  /// photo), where a near miss is worse than no match.
  static CatalogFood? exactMatch(String text) {
    final cleaned = _normalizeAlias(text);
    if (cleaned.isEmpty) return null;
    final singular = cleaned.split(' ').map(_singular).join(' ');
    for (final (alias, food, _) in _index) {
      if ((alias == cleaned || alias == singular) && !_genericAliases.contains(alias)) return food;
    }
    return null;
  }

  /// Everyday words that a typed description may use for one food ("chicken" →
  /// chicken breast), but that name a whole category when they come from a
  /// photo label — so they never match one specific food there.
  static const _genericAliases = {
    'chicken',
    'pork',
    'beef',
    'fish',
    'egg',
    'itlog',
    'tuna',
    'rice',
    'bread',
    'pasta',
    'spaghetti',
    'pancit',
    'pansit',
    'noodle soup',
    'ramen',
    'cereal',
    'porridge',
    'soup',
    'clear soup',
    'curry',
    'vegetables',
    'veggies',
    'gulay',
    'mixed vegetables',
    'salad',
    'sausage',
    'bbq',
    'barbecue',
    'inihaw',
    'satay',
    'kebab',
    'dumpling',
    'gyoza',
    'wonton',
    'spring roll',
    'egg roll',
    'steamed bun',
    'rice cake',
    'juice',
    'shake',
    'coffee',
    'tea',
    'chocolate',
    'biscuit',
    'custard',
    'bread roll',
    'sandwich',
    'nilaga',
  };

  static ({CatalogFood food, String? brand})? _match(String text) {
    final cleaned = _normalizeAlias(text);
    if (cleaned.isEmpty) return null;
    final singular = cleaned.split(' ').map(_singular).join(' ');
    for (final candidate in {cleaned, singular}) {
      final padded = ' $candidate ';
      for (final (alias, food, brand) in _index) {
        if (padded.contains(' $alias ')) return (food: food, brand: brand);
      }
    }
    return _fuzzy(singular);
  }

  /// Small typos ("spagheti"): one edit for short names, two for long ones.
  static ({CatalogFood food, String? brand})? _fuzzy(String text) {
    final words = text.split(' ');
    ({CatalogFood food, String? brand})? best;
    var bestDistance = 99;
    var bestLength = 0;
    for (final (alias, food, brand) in _index) {
      if (alias.length < 5) continue;
      final n = alias.split(' ').length;
      final allowed = alias.length >= 8 ? 2 : 1;
      for (var i = 0; i + n <= words.length; i++) {
        final window = words.sublist(i, i + n).join(' ');
        if ((window.length - alias.length).abs() > allowed) continue;
        final d = _distance(window, alias);
        if (d <= allowed && (d < bestDistance || (d == bestDistance && alias.length > bestLength))) {
          best = (food: food, brand: brand);
          bestDistance = d;
          bestLength = alias.length;
        }
      }
    }
    return best;
  }

  static String _singular(String w) {
    if (w.length <= 3) return w;
    if (w.endsWith('ies') && w.length > 4) return '${w.substring(0, w.length - 3)}y';
    if (w.endsWith('oes') || w.endsWith('ches') || w.endsWith('shes') || w.endsWith('xes')) {
      return w.substring(0, w.length - 2);
    }
    if (w.endsWith('s') && !w.endsWith('ss')) return w.substring(0, w.length - 1);
    return w;
  }

  static int _distance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current[j] = math.min(math.min(current[j - 1] + 1, previous[j] + 1), previous[j - 1] + cost);
      }
      previous = current;
    }
    return previous[b.length];
  }
}
