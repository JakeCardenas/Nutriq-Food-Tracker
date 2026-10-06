import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../domain/models/settings.dart';
import '../domain/models/user_profile.dart';
import '../domain/starting_point.dart';

/// Profile, goals and app settings.
class ProfileController extends ChangeNotifier {
  ProfileController(this._store);

  final LocalStore _store;

  UserProfile? _profile;
  AppSettings _settings = const AppSettings();

  UserProfile? get profile => _profile;
  AppSettings get settings => _settings;

  Future<void> load() async {
    _profile = await _store.loadProfile();
    _settings = await _store.loadSettings();
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    notifyListeners();
    await _store.saveProfile(profile);
  }

  /// Finishes first launch. [profile] may be null when the person skipped setup.
  Future<void> completeOnboarding(UserProfile? profile) async {
    if (profile != null) await saveProfile(profile);
    await updateSettings(_settings.copyWith(onboardingComplete: true));
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    notifyListeners();
    await _store.saveSettings(settings);
  }

  /// Saves (or removes) the calorie goal. Refuses ranges the calculator would
  /// never allow — below max(1,200, resting energy) — and any goal for minors.
  Future<void> setCalorieGoal(CalorieRange? range) async {
    final current = _profile ?? const UserProfile();
    if (range != null) {
      if (current.isMinor) throw const CalorieGoalRejected('Calorie goals aren’t offered for people under 18.');
      final problem = CalorieBounds.validate(range, current);
      if (problem != null) throw CalorieGoalRejected(problem);
    }
    await saveProfile(current.copyWith(calorieGoal: range));
  }

  Future<void> setProteinTarget(int? grams) =>
      saveProfile((_profile ?? const UserProfile()).copyWith(proteinTargetG: grams));

  /// Deletes the profile (and goals) but keeps meals and settings.
  Future<void> clearProfile() async {
    _profile = null;
    notifyListeners();
    await _store.clearProfile();
  }

  /// Deletes everything in the store and returns to first launch.
  Future<void> resetAll() async {
    await _store.wipe();
    _profile = null;
    _settings = const AppSettings();
    notifyListeners();
  }
}

class CalorieGoalRejected implements Exception {
  const CalorieGoalRejected(this.message);
  final String message;
  @override
  String toString() => message;
}
