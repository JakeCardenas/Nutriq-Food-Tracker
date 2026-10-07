import '../domain/models/meal.dart';
import '../domain/models/saved_food.dart';
import '../domain/models/scan_draft.dart';
import '../domain/models/scan_feedback.dart';
import '../domain/models/settings.dart';
import '../domain/models/user_profile.dart';
import 'sync_models.dart';

/// On-device persistence for one mode: the local-only file, or one signed-in
/// account's file. Nothing here leaves the phone; the sync engine reads the
/// pending records and pushes them only for a signed-in account.
abstract interface class LocalStore {
  // ── app data ───────────────────────────────────────────────────────────
  Future<UserProfile?> loadProfile();
  Future<void> saveProfile(UserProfile profile);
  Future<void> clearProfile();

  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);

  /// All meals, oldest first (deleted ones excluded).
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

  /// Deletes every row in every table of this file (this device only).
  Future<void> wipe();

  // ── device-only data (never synced) ────────────────────────────────────
  Future<List<ScanDraft>> scanDrafts();
  Future<void> upsertDraft(ScanDraft draft);
  Future<void> deleteDraft(String id);

  Future<String?> readMeta(String key);
  Future<void> writeMeta(String key, String? value);

  Future<bool> wasWrittenToHealth(String mealId);
  Future<void> recordHealthWrite(String mealId);

  /// The meal's Apple Health entry was deleted.
  Future<void> forgetHealthWrite(String mealId);

  // ── sync bookkeeping ───────────────────────────────────────────────────
  /// True for account files: edits are tracked and deletions leave tombstones.
  bool get tracksChanges;

  Future<List<SyncRecord>> pendingRecords();
  Future<int> pendingCount();
  Future<SyncRecord?> record(SyncEntity entity, String id);

  /// Clears the pending flag if the row hasn't changed since [pushed] was read.
  Future<void> markSynced(SyncRecord pushed);

  /// Writes a cloud version as clean (deletions remove the row).
  Future<void> applyRemote(SyncRecord remote);

  Future<List<SyncConflict>> conflicts();
  Future<void> addConflict(SyncConflict conflict);
  Future<void> removeConflict(String id);

  Future<void> close();
}
