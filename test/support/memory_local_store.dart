import 'package:nutriq/data/local_store.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/saved_food.dart';
import 'package:nutriq/domain/models/scan_feedback.dart';
import 'package:nutriq/domain/models/settings.dart';
import 'package:nutriq/domain/models/user_profile.dart';

/// In-memory [LocalStore] for controller and widget tests.
class MemoryLocalStore implements LocalStore {
  MemoryLocalStore({this._profile, this._settings = const AppSettings(), List<Meal>? meals})
    : _meals = {for (final m in meals ?? const <Meal>[]) m.id: m};

  UserProfile? _profile;
  AppSettings _settings;
  final Map<String, Meal> _meals;
  final Map<String, SavedFood> _saved = {};
  final List<ScanFeedback> _feedback = [];

  @override
  Future<UserProfile?> loadProfile() async => _profile;
  @override
  Future<void> saveProfile(UserProfile profile) async => _profile = profile;
  @override
  Future<void> clearProfile() async => _profile = null;

  @override
  Future<AppSettings> loadSettings() async => _settings;
  @override
  Future<void> saveSettings(AppSettings settings) async => _settings = settings;

  @override
  Future<List<Meal>> allMeals() async =>
      _meals.values.toList()..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  @override
  Future<void> upsertMeal(Meal meal) async => _meals[meal.id] = meal;
  @override
  Future<void> deleteMeal(String id) async => _meals.remove(id);
  @override
  Future<void> deleteAllMeals() async => _meals.clear();

  @override
  Future<List<SavedFood>> savedFoods() async =>
      _saved.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  @override
  Future<void> addSavedFood(SavedFood food) async => _saved[food.id] = food;
  @override
  Future<void> deleteSavedFood(String id) async => _saved.remove(id);

  @override
  Future<List<ScanFeedback>> feedback() async =>
      [..._feedback]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  @override
  Future<void> addFeedback(ScanFeedback feedback) async => _feedback.add(feedback);

  @override
  Future<void> wipe() async {
    _profile = null;
    _settings = const AppSettings();
    _meals.clear();
    _saved.clear();
    _feedback.clear();
  }
}
