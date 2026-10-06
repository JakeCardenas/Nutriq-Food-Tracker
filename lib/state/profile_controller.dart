import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../domain/models/settings.dart';
import '../domain/models/user_profile.dart';

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

  Future<void> setCalorieGoal(CalorieRange? range) =>
      saveProfile((_profile ?? const UserProfile()).copyWith(calorieGoal: range));

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
