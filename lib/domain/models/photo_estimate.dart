import 'dart:math' as math;

import '../ids.dart';
import 'food_item.dart';
import 'nutrition.dart';

/// Where a food's per-100 g nutrition came from.
enum NutritionSource {
  /// Nutriq's built-in food list.
  catalog,

  /// USDA FoodData Central (public domain).
  usda,

  /// No trusted entry — no nutrition is shown or invented.
  none,
}

/// A USDA FoodData Central entry, with nutrition per 100 g.
class UsdaFood {
  const UsdaFood({
    required this.fdcId,
    required this.description,
    this.dataType,
    required this.kcal100,
    required this.protein100,
    this.carbs100,
    this.fat100,
  });

  final int fdcId;

  /// USDA's name for it ("Fish, tuna, light, canned in oil, drained solids").
  final String description;

  /// "Foundation", "SR Legacy" or "Survey (FNDDS)".
  final String? dataType;
  final double kcal100;
  final double protein100;
  final double? carbs100;
  final double? fat100;

  Map<String, Object?> toJson() => {
    'fdcId': fdcId,
    'description': description,
    'dataType': dataType,
    'kcal100': kcal100,
    'protein100': protein100,
    'carbs100': carbs100,
    'fat100': fat100,
  };

  factory UsdaFood.fromJson(Map<String, Object?> j) => UsdaFood(
    fdcId: j['fdcId'] as int,
    description: j['description'] as String,
    dataType: j['dataType'] as String?,
    kcal100: (j['kcal100'] as num).toDouble(),
    protein100: (j['protein100'] as num).toDouble(),
    carbs100: (j['carbs100'] as num?)?.toDouble(),
    fat100: (j['fat100'] as num?)?.toDouble(),
  );
}

/// One food the photo analysis suggested, with nutrition per 100 g from a
/// trusted source (or none). Amounts are estimates the person confirms; the
/// model never supplies calories.
class EstimatedFood {
  const EstimatedFood({
    required this.name,
    this.localName,
    this.inferred = false,
    this.photoLow,
    this.photoHigh,
    this.portionNote,
    this.source = NutritionSource.none,
    this.matchName,
    this.dataType,
    this.fdcId,
    this.kcal100,
    this.protein100,
    this.carbs100,
    this.fat100,
    this.typicalGrams,
    this.usdaOptions = const [],
    this.pickedByPerson = false,
    this.alternatives = const [],
  });

  /// Generic name from the analysis ("white rice, cooked").
  final String name;
  final String? localName;

  /// Usually part of the dish but not visible in the photo (oil, sauce).
  final bool inferred;

  /// The amount range the photo suggests, in grams — null when it couldn't tell.
  final double? photoLow;
  final double? photoHigh;
  final String? portionNote;

  final NutritionSource source;

  /// The matched entry's name (food-list name or USDA description).
  final String? matchName;

  /// The USDA entry's data type ("SR Legacy"…), for USDA matches.
  final String? dataType;
  final int? fdcId;
  final double? kcal100;
  final double? protein100;
  final double? carbs100;
  final double? fat100;

  /// A food-list match's usual serving, used when the photo gave no amount.
  final double? typicalGrams;

  /// USDA entries that could be this food when none was clearly it. None is
  /// used until the person picks one ([withUsda]).
  final List<UsdaFood> usdaOptions;

  /// The person chose the USDA entry from [usdaOptions].
  final bool pickedByPerson;

  /// Other foods this could be, when the photo was ambiguous (≤ 2). The person
  /// can switch to one in the review.
  final List<String> alternatives;

  bool get hasNutrition => source != NutritionSource.none && kcal100 != null && protein100 != null;
  bool get gramsFromPhoto => photoLow != null && photoHigh != null;

  /// What the person sees: the local name if there is one.
  String get displayName => _capitalized(localName ?? name);

  /// Starting amount: the middle of the photo's range, else the typical
  /// serving of a food-list match, else nothing (the person chooses).
  double? get suggestedGrams => gramsFromPhoto ? ((photoLow! + photoHigh!) / 2).roundToDouble() : typicalGrams;

  NutritionTotals? totalsFor(double grams) => hasNutrition
      ? NutritionTotals(
          calories: kcal100! * grams / 100,
          protein: protein100! * grams / 100,
          carbs: (carbs100 ?? 0) * grams / 100,
          fat: (fat100 ?? 0) * grams / 100,
        )
      : null;

  /// This food with the USDA entry the person picked from [usdaOptions]. The
  /// amount stays the photo's estimate until they change it.
  EstimatedFood withUsda(UsdaFood usda) => EstimatedFood(
    name: name,
    localName: localName,
    inferred: inferred,
    photoLow: photoLow,
    photoHigh: photoHigh,
    portionNote: portionNote,
    source: NutritionSource.usda,
    matchName: usda.description,
    dataType: usda.dataType,
    fdcId: usda.fdcId,
    kcal100: usda.kcal100,
    protein100: usda.protein100,
    carbs100: usda.carbs100,
    fat100: usda.fat100,
    usdaOptions: usdaOptions,
    pickedByPerson: true,
    alternatives: alternatives,
  );

  /// The ingredient that is added once the person confirms [grams]. Nutriq's cloud accepts up to
  /// 5,000 kcal per serving, so a very large amount becomes equal servings (2,000 g of oil → 4 × 500 g).
  FoodItem toItem(double grams) {
    if (!hasNutrition) throw StateError('no nutrition for $name');
    final servings = math.max(1, (kcal100! * grams / 100 / _maxKcalPerServing).ceil());
    final each = grams / servings;
    double per(double? per100) => ((per100 ?? 0) * each / 100 * 10).round() / 10;
    return FoodItem(
      id: newId(),
      name: source == NutritionSource.catalog && matchName != null ? matchName! : _capitalized(name),
      servings: servings.toDouble(),
      servingLabel: '${each.round()} g',
      caloriesPerServing: per(kcal100),
      proteinPerServing: per(protein100),
      carbsPerServing: per(carbs100),
      fatPerServing: per(fat100),
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'localName': localName,
    'inferred': inferred,
    'photoLow': photoLow,
    'photoHigh': photoHigh,
    'portionNote': portionNote,
    'source': source.name,
    'matchName': matchName,
    'dataType': dataType,
    'fdcId': fdcId,
    'kcal100': kcal100,
    'protein100': protein100,
    'carbs100': carbs100,
    'fat100': fat100,
    'typicalGrams': typicalGrams,
    'usdaOptions': [for (final o in usdaOptions) o.toJson()],
    'pickedByPerson': pickedByPerson,
    'alternatives': alternatives,
  };

  factory EstimatedFood.fromJson(Map<String, Object?> j) {
    double? d(String k) => (j[k] as num?)?.toDouble();
    return EstimatedFood(
      name: j['name'] as String,
      localName: j['localName'] as String?,
      inferred: j['inferred'] as bool? ?? false,
      photoLow: d('photoLow'),
      photoHigh: d('photoHigh'),
      portionNote: j['portionNote'] as String?,
      source: NutritionSource.values.asNameMap()[j['source']] ?? NutritionSource.none,
      matchName: j['matchName'] as String?,
      dataType: j['dataType'] as String?,
      fdcId: j['fdcId'] as int?,
      kcal100: d('kcal100'),
      protein100: d('protein100'),
      carbs100: d('carbs100'),
      fat100: d('fat100'),
      typicalGrams: d('typicalGrams'),
      usdaOptions: [
        for (final o in (j['usdaOptions'] as List?) ?? const []) UsdaFood.fromJson((o as Map).cast<String, Object?>()),
      ],
      pickedByPerson: j['pickedByPerson'] as bool? ?? false,
      alternatives: [for (final a in (j['alternatives'] as List?) ?? const []) a as String],
    );
  }

  static String _capitalized(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static const _maxKcalPerServing = 5000;
}

/// A photo's candidate dish and foods, for the person to review and confirm.
class PhotoEstimate {
  const PhotoEstimate({
    this.dish,
    this.alternatives = const [],
    this.foods = const [],
    this.uncertainties = const [],
    this.nutritionLookup,
  });

  final String? dish;
  final List<String> alternatives;
  final List<EstimatedFood> foods;

  /// What a photo can't show (hidden oil or sauce, recipe, size…).
  final List<String> uncertainties;

  /// Whether the server could look foods up in USDA: "fdc", "not_configured" or "unavailable".
  final String? nutritionLookup;

  /// Sum of grams × per-100 g values for foods with nutrition and an amount.
  static NutritionTotals totalFor(Iterable<(EstimatedFood, double?)> amounts) => NutritionTotals.sum([
    for (final (food, grams) in amounts)
      if (grams != null) ?food.totalsFor(grams),
  ]);

  Map<String, Object?> toJson() => {
    'dish': dish,
    'alternatives': alternatives,
    'foods': [for (final f in foods) f.toJson()],
    'uncertainties': uncertainties,
    'nutritionLookup': nutritionLookup,
  };

  factory PhotoEstimate.fromJson(Map<String, Object?> j) => PhotoEstimate(
    dish: j['dish'] as String?,
    alternatives: [for (final a in (j['alternatives'] as List?) ?? const []) a as String],
    foods: [
      for (final f in (j['foods'] as List?) ?? const []) EstimatedFood.fromJson((f as Map).cast<String, Object?>()),
    ],
    uncertainties: [for (final u in (j['uncertainties'] as List?) ?? const []) u as String],
    nutritionLookup: j['nutritionLookup'] as String?,
  );
}
