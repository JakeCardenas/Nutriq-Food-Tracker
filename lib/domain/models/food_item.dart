import 'nutrition.dart';

/// One food in a meal. Nutrition is stored per serving and scaled by
/// [servings], so changing the portion never loses the base values.
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    this.servings = 1,
    this.servingLabel = '1 serving',
    required this.caloriesPerServing,
    this.proteinPerServing = 0,
    this.carbsPerServing = 0,
    this.fatPerServing = 0,
    this.confidence,
  });

  final String id;
  final String name;
  final double servings;
  final String servingLabel;
  final double caloriesPerServing;
  final double proteinPerServing;
  final double carbsPerServing;
  final double fatPerServing;

  /// 0–1 from a real analyzer; null for demo, manual or saved foods.
  final double? confidence;

  NutritionTotals get totals {
    if (servings <= 0 || servings.isNaN) return NutritionTotals.zero;
    return NutritionTotals(
      calories: caloriesPerServing * servings,
      protein: proteinPerServing * servings,
      carbs: carbsPerServing * servings,
      fat: fatPerServing * servings,
    );
  }

  bool get isLowConfidence => confidence != null && confidence! < 0.6;

  FoodItem copyWith({
    String? id,
    String? name,
    double? servings,
    String? servingLabel,
    double? caloriesPerServing,
    double? proteinPerServing,
    double? carbsPerServing,
    double? fatPerServing,
    double? confidence,
  }) => FoodItem(
    id: id ?? this.id,
    name: name ?? this.name,
    servings: servings ?? this.servings,
    servingLabel: servingLabel ?? this.servingLabel,
    caloriesPerServing: caloriesPerServing ?? this.caloriesPerServing,
    proteinPerServing: proteinPerServing ?? this.proteinPerServing,
    carbsPerServing: carbsPerServing ?? this.carbsPerServing,
    fatPerServing: fatPerServing ?? this.fatPerServing,
    confidence: confidence ?? this.confidence,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'servings': servings,
    'servingLabel': servingLabel,
    'kcal': caloriesPerServing,
    'protein': proteinPerServing,
    'carbs': carbsPerServing,
    'fat': fatPerServing,
    if (confidence != null) 'confidence': confidence,
  };

  factory FoodItem.fromJson(Map<String, Object?> j) => FoodItem(
    id: j['id'] as String,
    name: j['name'] as String,
    servings: (j['servings'] as num).toDouble(),
    servingLabel: j['servingLabel'] as String,
    caloriesPerServing: (j['kcal'] as num).toDouble(),
    proteinPerServing: (j['protein'] as num).toDouble(),
    carbsPerServing: (j['carbs'] as num).toDouble(),
    fatPerServing: (j['fat'] as num).toDouble(),
    confidence: (j['confidence'] as num?)?.toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is FoodItem &&
      other.id == id &&
      other.name == name &&
      other.servings == servings &&
      other.servingLabel == servingLabel &&
      other.caloriesPerServing == caloriesPerServing &&
      other.proteinPerServing == proteinPerServing &&
      other.carbsPerServing == carbsPerServing &&
      other.fatPerServing == fatPerServing &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    servings,
    servingLabel,
    caloriesPerServing,
    proteinPerServing,
    carbsPerServing,
    fatPerServing,
    confidence,
  );
}
