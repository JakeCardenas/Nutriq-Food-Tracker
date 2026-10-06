import 'package:nutriq/data/local_store.dart';
import 'package:nutriq/data/sync_models.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/saved_food.dart';
import 'package:nutriq/domain/models/scan_draft.dart';
import 'package:nutriq/domain/models/scan_feedback.dart';
import 'package:nutriq/domain/models/settings.dart';
import 'package:nutriq/domain/models/user_profile.dart';

class _Row {
  _Row(this.json, this.updatedAt, {this.dirty = false});
  Map<String, Object?> json;
  int updatedAt;
  bool dirty;
  bool deleted = false;
}

/// In-memory [LocalStore] for controller and widget tests. Mirrors the
/// SQLite store's sync semantics (tombstones only when [tracksChanges]).
class MemoryLocalStore implements LocalStore {
  MemoryLocalStore({
    UserProfile? profile,
    AppSettings settings = const AppSettings(),
    List<Meal>? meals,
    this.tracksChanges = false,
    int Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch) {
    _profile = profile?.toJson();
    _settings = settings;
    for (final m in meals ?? const <Meal>[]) {
      _tables[SyncEntity.meal]![m.id] = _Row(m.toJson(), 0);
    }
  }

  @override
  final bool tracksChanges;
  final int Function() _clock;
  bool closed = false;

  Map<String, Object?>? _profile;
  AppSettings _settings = const AppSettings();
  int _profileUpdated = 0;
  bool _profileDirty = false;
  final Map<SyncEntity, Map<String, _Row>> _tables = {
    SyncEntity.meal: {},
    SyncEntity.savedFood: {},
    SyncEntity.scanFeedback: {},
  };
  final Map<String, ScanDraft> _drafts = {};
  final Map<String, String> _meta = {};
  final Set<String> _healthWrites = {};
  final Map<String, SyncConflict> _conflicts = {};

  void _touchProfile() {
    if (!tracksChanges) return;
    _profileUpdated = _clock();
    _profileDirty = true;
  }

  void _put(SyncEntity e, String id, Map<String, Object?> json) =>
      _tables[e]![id] = _Row(json, _clock(), dirty: tracksChanges);

  void _remove(SyncEntity e, String id) {
    final row = _tables[e]![id];
    if (row == null) return;
    if (tracksChanges) {
      row
        ..deleted = true
        ..dirty = true
        ..updatedAt = _clock();
    } else {
      _tables[e]!.remove(id);
    }
  }

  Iterable<Map<String, Object?>> _live(SyncEntity e) => _tables[e]!.values.where((r) => !r.deleted).map((r) => r.json);

  @override
  Future<UserProfile?> loadProfile() async => _profile == null ? null : UserProfile.fromJson(_profile!);
  @override
  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile.toJson();
    _touchProfile();
  }

  @override
  Future<void> clearProfile() async {
    _profile = null;
    _touchProfile();
  }

  @override
  Future<AppSettings> loadSettings() async => _settings;
  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
    _touchProfile();
  }

  @override
  Future<List<Meal>> allMeals() async =>
      _live(SyncEntity.meal).map(Meal.fromJson).toList()..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  @override
  Future<void> upsertMeal(Meal meal) async => _put(SyncEntity.meal, meal.id, meal.toJson());
  @override
  Future<void> deleteMeal(String id) async => _remove(SyncEntity.meal, id);
  @override
  Future<void> deleteAllMeals() async {
    for (final id in _tables[SyncEntity.meal]!.keys.toList()) {
      _remove(SyncEntity.meal, id);
    }
  }

  @override
  Future<List<SavedFood>> savedFoods() async =>
      _live(SyncEntity.savedFood).map(SavedFood.fromJson).toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  @override
  Future<void> addSavedFood(SavedFood food) async => _put(SyncEntity.savedFood, food.id, food.toJson());
  @override
  Future<void> deleteSavedFood(String id) async => _remove(SyncEntity.savedFood, id);

  @override
  Future<List<ScanFeedback>> feedback() async =>
      _live(SyncEntity.scanFeedback).map(ScanFeedback.fromJson).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  @override
  Future<void> addFeedback(ScanFeedback feedback) async =>
      _put(SyncEntity.scanFeedback, feedback.id, feedback.toJson());

  @override
  Future<List<ScanDraft>> scanDrafts() async =>
      _drafts.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  @override
  Future<void> upsertDraft(ScanDraft draft) async => _drafts[draft.id] = draft;
  @override
  Future<void> deleteDraft(String id) async => _drafts.remove(id);

  @override
  Future<String?> readMeta(String key) async => _meta[key];
  @override
  Future<void> writeMeta(String key, String? value) async {
    if (value == null) {
      _meta.remove(key);
    } else {
      _meta[key] = value;
    }
  }

  @override
  Future<bool> wasWrittenToHealth(String mealId) async => _healthWrites.contains(mealId);
  @override
  Future<void> recordHealthWrite(String mealId) async => _healthWrites.add(mealId);

  SyncRecord _profileRecord() => SyncRecord(
    entity: SyncEntity.profile,
    id: 'me',
    updatedAt: _profileUpdated,
    pending: _profileDirty,
    json: {'profile': _profile, 'settings': _settings.toJson()},
  );

  SyncRecord _rowRecord(SyncEntity e, String id, _Row r) => SyncRecord(
    entity: e,
    id: id,
    updatedAt: r.updatedAt,
    deleted: r.deleted,
    pending: r.dirty,
    json: r.deleted ? null : r.json,
  );

  @override
  Future<List<SyncRecord>> pendingRecords() async {
    if (!tracksChanges) return const [];
    return [
      if (_profileDirty) _profileRecord(),
      for (final MapEntry(key: e, value: rows) in _tables.entries)
        for (final MapEntry(key: id, value: r) in rows.entries)
          if (r.dirty) _rowRecord(e, id, r),
    ];
  }

  @override
  Future<int> pendingCount() async => (await pendingRecords()).length;

  @override
  Future<SyncRecord?> record(SyncEntity entity, String id) async {
    if (entity == SyncEntity.profile) return _profileRecord();
    final r = _tables[entity]![id];
    return r == null ? null : _rowRecord(entity, id, r);
  }

  @override
  Future<void> markSynced(SyncRecord pushed) async {
    if (pushed.entity == SyncEntity.profile) {
      if (_profileUpdated == pushed.updatedAt) _profileDirty = false;
      return;
    }
    final r = _tables[pushed.entity]![pushed.id];
    if (r == null || r.updatedAt != pushed.updatedAt) return;
    if (r.deleted) {
      _tables[pushed.entity]!.remove(pushed.id);
    } else {
      r.dirty = false;
    }
  }

  @override
  Future<void> applyRemote(SyncRecord remote) async {
    if (remote.entity == SyncEntity.profile) {
      final json = remote.json ?? const {};
      _profile = (json['profile'] as Map?)?.cast<String, Object?>();
      final settings = json['settings'];
      if (settings != null) _settings = AppSettings.fromJson((settings as Map).cast<String, Object?>());
      _profileUpdated = remote.updatedAt;
      _profileDirty = false;
      return;
    }
    if (remote.deleted || remote.json == null) {
      _tables[remote.entity]!.remove(remote.id);
    } else {
      _tables[remote.entity]![remote.id] = _Row(remote.json!, remote.updatedAt);
    }
  }

  @override
  Future<List<SyncConflict>> conflicts() async => _conflicts.values.toList();
  @override
  Future<void> addConflict(SyncConflict conflict) async => _conflicts[conflict.id] = conflict;
  @override
  Future<void> removeConflict(String id) async => _conflicts.remove(id);

  @override
  Future<void> wipe() async {
    _profile = null;
    _settings = const AppSettings();
    _profileDirty = false;
    for (final t in _tables.values) {
      t.clear();
    }
    _drafts.clear();
    _meta.clear();
    _healthWrites.clear();
    _conflicts.clear();
  }

  @override
  Future<void> close() async => closed = true;
}
