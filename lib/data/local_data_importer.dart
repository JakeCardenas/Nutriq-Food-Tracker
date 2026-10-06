import 'local_store.dart';
import 'sync_models.dart';

class ImportSummary {
  const ImportSummary({
    required this.meals,
    required this.savedFoods,
    required this.feedback,
    required this.hasProfile,
    required this.alreadyImported,
  });

  final int meals;
  final int savedFoods;
  final int feedback;
  final bool hasProfile;
  final bool alreadyImported;

  bool get isEmpty => meals == 0 && savedFoods == 0 && feedback == 0 && !hasProfile;
}

class ImportResult {
  const ImportResult({this.meals = 0, this.savedFoods = 0, this.feedback = 0, this.profileKept = false});
  final int meals;
  final int savedFoods;
  final int feedback;

  /// True when the account already had a profile, so the local one wasn't copied.
  final bool profileKept;
}

/// Copies this phone's local-only data into a signed-in account's file, where it
/// becomes pending uploads. Never deletes local-only data, never overwrites rows
/// the account already has, and remembers the import so it can't run twice.
abstract final class LocalDataImporter {
  static String _flag(String userId) => 'imported_to:$userId';

  static Future<ImportSummary> summarize(LocalStore source, {required String userId}) async => ImportSummary(
    meals: (await source.allMeals()).length,
    savedFoods: (await source.savedFoods()).length,
    feedback: (await source.feedback()).length,
    hasProfile: await source.loadProfile() != null,
    alreadyImported: await source.readMeta(_flag(userId)) != null,
  );

  static Future<ImportResult> importInto({
    required LocalStore source,
    required LocalStore target,
    required String userId,
    required Future<String?> Function(String photoPath) copyPhoto,
  }) async {
    if (await source.readMeta(_flag(userId)) != null) return const ImportResult();

    var profileKept = false;
    final profile = await source.loadProfile();
    if (profile != null) {
      if (await target.loadProfile() == null) {
        await target.saveProfile(profile);
        final settings = await source.loadSettings();
        await target.saveSettings(settings.copyWith(onboardingComplete: true));
      } else {
        profileKept = true;
      }
    }

    var meals = 0, foods = 0, feedback = 0;
    for (final meal in await source.allMeals()) {
      if (await target.record(SyncEntity.meal, meal.id) != null) continue;
      final photo = meal.photoPath == null ? null : await copyPhoto(meal.photoPath!);
      await target.upsertMeal(meal.copyWith(photoPath: photo));
      meals++;
    }
    for (final food in await source.savedFoods()) {
      if (await target.record(SyncEntity.savedFood, food.id) != null) continue;
      await target.addSavedFood(food);
      foods++;
    }
    for (final fb in await source.feedback()) {
      if (await target.record(SyncEntity.scanFeedback, fb.id) != null) continue;
      await target.addFeedback(fb);
      feedback++;
    }

    await source.writeMeta(_flag(userId), DateTime.now().toIso8601String());
    return ImportResult(meals: meals, savedFoods: foods, feedback: feedback, profileKept: profileKept);
  }
}
