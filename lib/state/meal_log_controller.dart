import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../domain/day_boundary.dart';
import '../domain/ids.dart';
import '../domain/models/food_item.dart';
import '../domain/models/meal.dart';
import '../domain/models/nutrition.dart';
import '../domain/models/saved_food.dart';
import '../domain/models/scan_feedback.dart';
import '../services/coach/coach_service.dart' show DaySummary;

/// The meal log, "My foods" and scan feedback. Meals are small, so the whole
/// log is kept in memory and grouped into logical days on demand.
class MealLogController extends ChangeNotifier {
  MealLogController(this._store, {required this._dayStartHour, required this._deletePhoto});

  final LocalStore _store;
  final int Function() _dayStartHour;
  final Future<void> Function(String photoPath) _deletePhoto;

  final _saved = StreamController<Meal>.broadcast();

  /// Emits each meal right after it's saved (used for the Apple Health write-once hook).
  Stream<Meal> get mealSaved => _saved.stream;

  List<Meal> _meals = [];
  List<SavedFood> _savedFoods = [];
  List<ScanFeedback> _feedback = [];

  /// Oldest first.
  List<Meal> get meals => List.unmodifiable(_meals);
  List<SavedFood> get savedFoods => List.unmodifiable(_savedFoods);
  List<ScanFeedback> get feedback => List.unmodifiable(_feedback);

  int get dayStartHour => _dayStartHour();

  Future<void> load() async {
    _meals = await _store.allMeals();
    _savedFoods = await _store.savedFoods();
    _feedback = await _store.feedback();
    notifyListeners();
  }

  /// The logical day "now" belongs to.
  DateTime today([DateTime? now]) => logicalDay(now ?? DateTime.now(), dayStartHour);

  DateTime dayOf(Meal meal) => logicalDay(meal.loggedAt, dayStartHour);

  List<Meal> mealsForDay(DateTime day) {
    final d = dateOnly(day);
    return _meals.where((m) => dayOf(m) == d).toList();
  }

  NutritionTotals totalsForDay(DateTime day) => NutritionTotals.sum(mealsForDay(day).map((m) => m.totals));

  /// [days] summaries ending on [day], oldest first.
  List<DaySummary> summariesEnding(DateTime day, {int days = 7}) => [
    for (var i = days - 1; i >= 0; i--)
      () {
        final d = DateTime(day.year, day.month, day.day - i);
        final dayMeals = mealsForDay(d);
        return DaySummary(
          day: d,
          totals: NutritionTotals.sum(dayMeals.map((m) => m.totals)),
          mealCount: dayMeals.length,
        );
      }(),
  ];

  Future<void> saveMeal(Meal meal) async {
    _meals = [..._meals.where((m) => m.id != meal.id), meal]..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    notifyListeners();
    await _store.upsertMeal(meal);
    _saved.add(meal);
  }

  @override
  void dispose() {
    _saved.close();
    super.dispose();
  }

  Future<void> deleteMeal(Meal meal) async {
    _meals = _meals.where((m) => m.id != meal.id).toList();
    notifyListeners();
    await _store.deleteMeal(meal.id);
    if (meal.photoPath != null) await _deletePhoto(meal.photoPath!);
  }

  Future<void> deleteAllMeals() async {
    final photos = _meals.map((m) => m.photoPath).whereType<String>().toList();
    _meals = [];
    notifyListeners();
    await _store.deleteAllMeals();
    for (final p in photos) {
      await _deletePhoto(p);
    }
  }

  /// Adds a food to "My foods" without logging a meal.
  Future<SavedFood> saveFood(FoodItem item) async {
    final saved = SavedFood(
      id: newId(),
      item: item.copyWith(id: newId(), servings: 1),
      savedAt: DateTime.now(),
    );
    _savedFoods = [saved, ..._savedFoods];
    notifyListeners();
    await _store.addSavedFood(saved);
    return saved;
  }

  Future<void> deleteSavedFood(String id) async {
    _savedFoods = _savedFoods.where((f) => f.id != id).toList();
    notifyListeners();
    await _store.deleteSavedFood(id);
  }

  /// Foods from recent meals, distinct by name, newest first.
  List<FoodItem> recentFoods({int limit = 20}) {
    final seen = <String>{};
    final out = <FoodItem>[];
    for (final meal in _meals.reversed) {
      for (final item in meal.items) {
        if (seen.add(item.name.trim().toLowerCase())) out.add(item);
        if (out.length >= limit) return out;
      }
    }
    return out;
  }

  /// Most recent photo-based meals, newest first (for scan feedback).
  List<Meal> recentScannedMeals({int limit = 10}) =>
      _meals.reversed.where((m) => m.source != MealSource.manual).take(limit).toList();

  Future<void> addFeedback(ScanFeedback feedback) async {
    _feedback = [feedback, ..._feedback];
    notifyListeners();
    await _store.addFeedback(feedback);
  }

  ScanFeedback? feedbackFor(String mealId) {
    for (final f in _feedback) {
      if (f.mealId == mealId) return f;
    }
    return null;
  }

  /// Reloads from the store (after a full reset).
  Future<void> reload() => load();
}
