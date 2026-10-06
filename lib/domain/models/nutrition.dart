/// Calories and macros. Every value in the app is an estimate.
class NutritionTotals {
  const NutritionTotals({this.calories = 0, this.protein = 0, this.carbs = 0, this.fat = 0});

  static const zero = NutritionTotals();

  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  NutritionTotals operator +(NutritionTotals o) => NutritionTotals(
    calories: calories + o.calories,
    protein: protein + o.protein,
    carbs: carbs + o.carbs,
    fat: fat + o.fat,
  );

  static NutritionTotals sum(Iterable<NutritionTotals> all) => all.fold(zero, (a, b) => a + b);

  /// Share of calories from each macro (4/4/9 kcal per gram), or null when
  /// there is nothing to split.
  ({double protein, double carbs, double fat})? get calorieSplit {
    final p = protein * 4, c = carbs * 4, f = fat * 9;
    final total = p + c + f;
    if (total <= 0) return null;
    return (protein: p / total, carbs: c / total, fat: f / total);
  }
}
