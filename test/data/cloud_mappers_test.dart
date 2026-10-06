import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/data/cloud_mappers.dart';
import 'package:nutriq/data/sync_models.dart';
import 'package:nutriq/domain/models/food_item.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/saved_food.dart';
import 'package:nutriq/domain/models/scan_feedback.dart';
import 'package:nutriq/domain/models/settings.dart';
import 'package:nutriq/domain/models/user_profile.dart';

/// What PostgREST would return for a row the push function just wrote.
Map<String, Object?> _serverRowFromMealParams(Map<String, Object?> meal, List<Map<String, Object?>> items) => {
  ...meal..remove('deleted'),
  'deleted_at': null,
  'updated_at': '2026-10-06T12:00:01.000001+00:00',
  'meal_items': [
    for (final (i, item) in items.indexed) {...item, 'position': i},
  ].reversed.toList(), // order isn't guaranteed; mapper sorts by position
};

void main() {
  final meal = Meal(
    id: 'm1',
    loggedAt: DateTime(2026, 10, 6, 12, 30),
    type: MealType.lunch,
    source: MealSource.demoScan,
    name: 'Bowl',
    photoPath: 'accounts/u/meal_photos/m1.jpg',
    items: const [
      FoodItem(
        id: 'a',
        name: 'Rice',
        servings: 1.5,
        servingLabel: '1 cup',
        caloriesPerServing: 200,
        proteinPerServing: 4,
        carbsPerServing: 45,
        fatPerServing: 0.5,
      ),
      FoodItem(id: 'b', name: 'Chicken', caloriesPerServing: 198, proteinPerServing: 37, confidence: 0.4),
    ],
  );

  test('meal round-trips through push params and a server row (photo stays local)', () {
    final record = SyncRecord(entity: SyncEntity.meal, id: 'm1', updatedAt: 42, json: meal.toJson());
    final params = CloudMappers.mealPushParams(record);
    final mealParams = (params['p_meal'] as Map).cast<String, Object?>();
    final items = (params['p_items'] as List).cast<Map<String, Object?>>();
    expect(mealParams['client_updated_at'], 42);
    expect(mealParams.containsKey('photo_path'), isFalse);
    expect(items.first['serving_label'], '1 cup');

    final back = CloudMappers.mealFromRow(_serverRowFromMealParams(mealParams, items));
    expect(back.updatedAt, 42);
    expect(back.deleted, isFalse);
    final restored = Meal.fromJson(back.json!);
    expect(restored.copyWith(photoPath: meal.photoPath), meal);
    expect(restored.photoPath, isNull);
  });

  test('a deleted meal pushes only what the server needs', () {
    final params = CloudMappers.mealPushParams(
      const SyncRecord(entity: SyncEntity.meal, id: 'm1', updatedAt: 9, deleted: true),
    );
    expect(params['p_meal'], {'id': 'm1', 'deleted': true, 'client_updated_at': 9});
    expect(params['p_items'], isEmpty);
  });

  test('a soft-deleted server row maps to a deletion', () {
    final rec = CloudMappers.mealFromRow({
      'id': 'm1',
      'logged_at': '2026-10-06T12:00:00Z',
      'meal_type': 'lunch',
      'source': 'manual',
      'deleted_at': '2026-10-07T00:00:00Z',
      'client_updated_at': 5,
      'meal_items': [],
    });
    expect(rec.deleted, isTrue);
    expect(rec.json, isNull);
  });

  test('profile and settings round-trip, including a cleared profile', () {
    const profile = UserProfile(
      age: 30,
      sex: SexForEstimate.male,
      heightCm: 180,
      weightKg: 80.5,
      activity: ActivityLevel.moderate,
      goal: FitnessGoal.buildStrength,
      workoutDaysPerWeek: 3,
      health: {HealthConsideration.breastfeeding},
      calorieGoal: CalorieRange(min: 2750, max: 3000, custom: true),
      proteinTargetG: 130,
    );
    const settings = AppSettings(units: UnitSystem.imperial, dayStartHour: 4, onboardingComplete: true);
    final params = CloudMappers.profilePushParams(
      SyncRecord(
        entity: SyncEntity.profile,
        id: 'me',
        updatedAt: 7,
        json: {'profile': profile.toJson(), 'settings': settings.toJson()},
      ),
    );
    final p = (params['p'] as Map).cast<String, Object?>();
    expect(p['has_profile'], isTrue);
    expect(p['health_considerations'], ['breastfeeding']);

    final back = CloudMappers.profileFromRow({...p, 'updated_at': 'x'});
    expect(UserProfile.fromJson((back.json!['profile'] as Map).cast()), profile);
    expect(AppSettings.fromJson((back.json!['settings'] as Map).cast()), settings);
    expect(back.updatedAt, 7);

    final cleared = CloudMappers.profilePushParams(
      SyncRecord(
        entity: SyncEntity.profile,
        id: 'me',
        updatedAt: 8,
        json: {'profile': null, 'settings': settings.toJson()},
      ),
    );
    final clearedRow = (cleared['p'] as Map).cast<String, Object?>();
    expect(clearedRow['has_profile'], isFalse);
    expect(CloudMappers.profileFromRow(clearedRow).json!['profile'], isNull);
  });

  test('saved foods and scan feedback round-trip', () {
    final food = SavedFood(
      id: 's1',
      item: const FoodItem(id: 'x', name: 'Oats', servingLabel: '1 cup', caloriesPerServing: 150, proteinPerServing: 5),
      savedAt: DateTime.utc(2026, 10, 6, 8),
    );
    final foodParams =
        (CloudMappers.savedFoodPushParams(
                  SyncRecord(entity: SyncEntity.savedFood, id: 's1', updatedAt: 3, json: food.toJson()),
                )['p']
                as Map)
            .cast<String, Object?>();
    final foodBack = SavedFood.fromJson(CloudMappers.savedFoodFromRow({...foodParams, 'deleted_at': null}).json!);
    expect(foodBack.item.name, 'Oats');
    expect(foodBack.item.caloriesPerServing, 150);
    expect(foodBack.savedAt, food.savedAt.toLocal());

    final fb = ScanFeedback(
      id: 'f1',
      mealId: 'm1',
      mealSummary: 'Rice',
      estimatedCalories: 300,
      rating: FeedbackRating.tooHigh,
      wasDemo: true,
      createdAt: DateTime(2026, 10, 6, 13),
      note: 'smaller bowl',
    );
    final fbParams =
        (CloudMappers.feedbackPushParams(
                  SyncRecord(entity: SyncEntity.scanFeedback, id: 'f1', updatedAt: 4, json: fb.toJson()),
                )['p']
                as Map)
            .cast<String, Object?>();
    expect(ScanFeedback.fromJson(CloudMappers.feedbackFromRow({...fbParams, 'deleted_at': null}).json!), fb);
  });
}
