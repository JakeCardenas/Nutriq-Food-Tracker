import 'food_catalog.dart';
import 'meal_description.dart';
import 'models/photo_estimate.dart';

/// Turns the scan-photo function's validated JSON into a [PhotoEstimate]:
/// each food is matched to Nutriq's food list first (exact name, alias or
/// local name — never a partial or typo match), then to the USDA entry the
/// server found, else left without nutrition. When the server found several
/// possible USDA entries instead of a clear one, they're kept as options for
/// the person to pick from; none is used until they do.
abstract final class PhotoEstimateResolver {
  static PhotoEstimate? fromResponse(Map<String, Object?> json) {
    final rawFoods = json['foods'];
    if (rawFoods is! List) return null;
    final isFood = json['isFood'] == true;
    return PhotoEstimate(
      dish: _text(json['dish']),
      alternatives: _texts(json['dishAlternatives']),
      foods: isFood ? [for (final f in rawFoods) ?_food(f)] : const [],
      uncertainties: _texts(json['uncertainties']),
      nutritionLookup: _text(json['nutritionLookup']),
    );
  }

  static EstimatedFood? _food(Object? raw) {
    if (raw is! Map) return null;
    final name = _text(raw['name']);
    if (name == null) return null;
    final localName = _text(raw['localName']);
    final grams = raw['grams'];
    double? low, high;
    String? note;
    if (grams is Map) {
      final l = (grams['low'] as num?)?.toDouble();
      final h = (grams['high'] as num?)?.toDouble();
      if (l != null && h != null && l > 0 && h >= l && h <= 2000) {
        low = l;
        high = h;
        note = _text(grams['note']);
      }
    }
    final inferred = raw['visibility'] != 'visible';
    final alternatives = _alternatives(raw['alternatives'], name);

    final catalog =
        (localName == null ? null : MealDescription.exactMatch(localName)) ?? MealDescription.exactMatch(name);
    if (catalog != null) {
      return _fromCatalog(
        catalog,
        name: name,
        localName: localName,
        inferred: inferred,
        low: low,
        high: high,
        note: note,
        alternatives: alternatives,
      );
    }
    final fdc = raw['fdc'];
    final usda = fdc is Map ? _usda(fdc) : null;
    final rawOptions = raw['fdcOptions'];
    final options = usda != null || rawOptions is! List
        ? const <UsdaFood>[]
        : [
            for (final o in rawOptions)
              if (o is Map) ?_usda(o),
          ].take(_maxOptions).toList();
    return EstimatedFood(
      name: name,
      localName: localName,
      inferred: inferred,
      photoLow: low,
      photoHigh: high,
      portionNote: note,
      source: usda == null ? NutritionSource.none : NutritionSource.usda,
      matchName: usda?.description,
      dataType: usda?.dataType,
      fdcId: usda?.fdcId,
      kcal100: usda?.kcal100,
      protein100: usda?.protein100,
      carbs100: usda?.carbs100,
      fat100: usda?.fat100,
      usdaOptions: options,
      alternatives: alternatives,
    );
  }

  /// [food] as one of its [EstimatedFood.alternatives]: matched again to
  /// Nutriq's food list (exact names only), else left without nutrition. The
  /// photo's amount and notes stay — it's the same food on the plate.
  static EstimatedFood alternative(EstimatedFood food, String name) {
    final catalog = MealDescription.exactMatch(name);
    if (catalog != null) {
      return _fromCatalog(
        catalog,
        name: name,
        inferred: food.inferred,
        low: food.photoLow,
        high: food.photoHigh,
        note: food.portionNote,
      );
    }
    return EstimatedFood(
      name: name,
      inferred: food.inferred,
      photoLow: food.photoLow,
      photoHigh: food.photoHigh,
      portionNote: food.portionNote,
    );
  }

  static EstimatedFood _fromCatalog(
    CatalogFood catalog, {
    required String name,
    String? localName,
    required bool inferred,
    double? low,
    double? high,
    String? note,
    List<String> alternatives = const [],
  }) => EstimatedFood(
    name: name,
    localName: localName,
    inferred: inferred,
    photoLow: low,
    photoHigh: high,
    portionNote: note,
    source: NutritionSource.catalog,
    matchName: catalog.name,
    kcal100: catalog.kcal,
    protein100: catalog.protein,
    carbs100: catalog.carbs,
    fat100: catalog.fat,
    typicalGrams: catalog.portions[catalog.defaultUnit]!.grams,
    alternatives: alternatives,
  );

  /// Up to 2 other names: no repeats, not the food's own name.
  static List<String> _alternatives(Object? raw, String name) {
    final seen = {name.toLowerCase()};
    return [
      for (final a in _texts(raw))
        if (seen.add(a.toLowerCase())) a,
    ].take(2).toList();
  }

  static const _maxOptions = 4;

  static UsdaFood? _usda(Map fdc) {
    final id = fdc['fdcId'];
    final kcal = (fdc['kcal'] as num?)?.toDouble();
    final protein = (fdc['protein'] as num?)?.toDouble();
    final description = _text(fdc['description']);
    if (id is! int || id <= 0 || description == null) return null;
    if (kcal == null || protein == null || kcal < 0 || kcal > 900 || protein < 0 || protein > 100) return null;
    double? optional(Object? v) {
      final n = (v as num?)?.toDouble();
      return n != null && n >= 0 && n <= 100 ? n : null;
    }

    return UsdaFood(
      fdcId: id,
      description: description,
      dataType: _text(fdc['dataType']),
      kcal100: kcal,
      protein100: protein,
      carbs100: optional(fdc['carbs']),
      fat100: optional(fdc['fat']),
    );
  }

  static String? _text(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static List<String> _texts(Object? v) => [for (final x in v is List ? v : const []) ?_text(x)];
}
