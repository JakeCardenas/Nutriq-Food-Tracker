import 'models/user_profile.dart';

/// Daily macro references shown on the macro rings.
///
/// Protein is the person's own reference. Carbs and fat are derived from the
/// midpoint of their calorie goal: what's left after protein is split 55 % carbs /
/// 45 % fat by energy (or 50 % / 30 % of the goal when no protein reference is set),
/// within common dietary reference ranges. Minors get no references.
class MacroReferences {
  const MacroReferences({this.protein, this.carbs, this.fat});

  final int? protein;
  final int? carbs;
  final int? fat;

  static const none = MacroReferences();

  static MacroReferences forProfile(UserProfile? p) {
    if (p == null || p.isMinor) return none;
    final protein = p.proteinTargetG;
    final goal = p.calorieGoal;
    if (goal == null) return MacroReferences(protein: protein);
    final mid = goal.mid;
    if (protein != null) {
      final remaining = (mid - protein * 4).clamp(0, mid);
      return MacroReferences(
        protein: protein,
        carbs: _round5(remaining * 0.55 / 4),
        fat: _round5(remaining * 0.45 / 9),
      );
    }
    return MacroReferences(carbs: _round5(mid * 0.50 / 4), fat: _round5(mid * 0.30 / 9));
  }

  static int _round5(num v) => (v / 5).round() * 5;
}
