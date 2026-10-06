import '../domain/models/meal.dart';
import '../domain/models/saved_food.dart';
import '../domain/models/scan_feedback.dart';
import '../domain/models/settings.dart';
import '../domain/models/user_profile.dart';

/// On-device persistence. Nothing here leaves the phone.
abstract interface class LocalStore {
  Future<UserProfile?> loadProfile();
  Future<void> saveProfile(UserProfile profile);
  Future<void> clearProfile();

  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);

  /// All meals, oldest first.
  Future<List<Meal>> allMeals();
  Future<void> upsertMeal(Meal meal);
  Future<void> deleteMeal(String id);
  Future<void> deleteAllMeals();

  /// Newest first.
  Future<List<SavedFood>> savedFoods();
  Future<void> addSavedFood(SavedFood food);
  Future<void> deleteSavedFood(String id);

  /// Newest first.
  Future<List<ScanFeedback>> feedback();
  Future<void> addFeedback(ScanFeedback feedback);

  /// Deletes every row in every table.
  Future<void> wipe();
}
