import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/data/sqlite_local_store.dart';
import 'package:nutriq/domain/models/food_item.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/saved_food.dart';
import 'package:nutriq/domain/models/scan_feedback.dart';
import 'package:nutriq/domain/models/settings.dart';
import 'package:nutriq/domain/models/user_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _rice = FoodItem(id: 'f1', name: 'Rice', caloriesPerServing: 200, carbsPerServing: 45);

Meal _meal(String id, DateTime at) =>
    Meal(id: id, loggedAt: at, type: MealType.lunch, source: MealSource.manual, items: const [_rice]);

void main() {
  late SqliteLocalStore store;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    store = await SqliteLocalStore.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  });
  tearDown(() => store.close());

  test('meals: insert, update, order, delete', () async {
    await store.upsertMeal(_meal('b', DateTime(2026, 10, 6, 19)));
    await store.upsertMeal(_meal('a', DateTime(2026, 10, 6, 8)));
    expect((await store.allMeals()).map((m) => m.id), ['a', 'b']);

    final moved = _meal('a', DateTime(2026, 10, 5, 8));
    await store.upsertMeal(moved);
    final all = await store.allMeals();
    expect(all.length, 2);
    expect(all.first, moved);

    await store.deleteMeal('a');
    expect((await store.allMeals()).map((m) => m.id), ['b']);
  });

  test('profile: save, load, clear', () async {
    expect(await store.loadProfile(), isNull);
    const p = UserProfile(age: 30, goal: FitnessGoal.maintain);
    await store.saveProfile(p);
    expect(await store.loadProfile(), p);
    await store.clearProfile();
    expect(await store.loadProfile(), isNull);
  });

  test('settings default when nothing is stored', () async {
    expect(await store.loadSettings(), const AppSettings());
    const s = AppSettings(dayStartHour: 4, onboardingComplete: true);
    await store.saveSettings(s);
    expect(await store.loadSettings(), s);
  });

  test('saved foods and feedback', () async {
    final saved = SavedFood(id: 's1', item: _rice, savedAt: DateTime(2026, 10, 6));
    await store.addSavedFood(saved);
    expect(await store.savedFoods(), [saved]);
    await store.deleteSavedFood('s1');
    expect(await store.savedFoods(), isEmpty);

    final fb = ScanFeedback(
      id: 'fb1',
      mealId: 'm1',
      mealSummary: 'Rice',
      estimatedCalories: 200,
      rating: FeedbackRating.tooHigh,
      note: 'smaller bowl',
      wasDemo: true,
      createdAt: DateTime(2026, 10, 6, 12),
    );
    await store.addFeedback(fb);
    expect(await store.feedback(), [fb]);
  });

  test('wipe clears everything', () async {
    await store.upsertMeal(_meal('a', DateTime(2026, 10, 6)));
    await store.saveProfile(const UserProfile(age: 40));
    await store.saveSettings(const AppSettings(onboardingComplete: true));
    await store.addSavedFood(SavedFood(id: 's', item: _rice, savedAt: DateTime(2026)));
    await store.wipe();
    expect(await store.allMeals(), isEmpty);
    expect(await store.loadProfile(), isNull);
    expect(await store.loadSettings(), const AppSettings());
    expect(await store.savedFoods(), isEmpty);
  });
}
