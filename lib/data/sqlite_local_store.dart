import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/models/meal.dart';
import '../domain/models/saved_food.dart';
import '../domain/models/scan_draft.dart';
import '../domain/models/scan_feedback.dart';
import '../domain/models/settings.dart';
import '../domain/models/user_profile.dart';
import 'local_store.dart';
import 'sync_models.dart';

/// SQLite-backed [LocalStore]. Rows hold a JSON document plus the columns we
/// sort and sync by, which keeps schema changes cheap while the models evolve.
///
/// Schema v2 (Nutriq 0.2) adds `updated_at`, `deleted` and `dirty` to the
/// synced tables plus device-only tables for drafts, conflicts and Apple Health
/// writes. v1 files from the MVP are upgraded in place.
class SqliteLocalStore implements LocalStore {
  SqliteLocalStore._(this._db, this.tracksChanges, this._clock);

  final Database _db;
  final int Function() _clock;

  @override
  final bool tracksChanges;

  static const _profileKey = 'profile';
  static const _settingsKey = 'settings';
  static const _profileUpdatedKey = 'sync:profile:updated_at';
  static const _profileDirtyKey = 'sync:profile:dirty';
  static const _metaPrefix = 'meta:';
  static const _syncedTables = {
    SyncEntity.meal: 'meals',
    SyncEntity.savedFood: 'saved_foods',
    SyncEntity.scanFeedback: 'scan_feedback',
  };

  /// Default file name for local-only mode.
  static const localFileName = 'nutriq.db';

  /// File name for a signed-in account's cache.
  static String accountFileName(String userId) => 'nutriq_$userId.db';

  /// Opens (or creates/upgrades) a database. Pass [factory]/[path] in tests.
  static Future<SqliteLocalStore> open({
    DatabaseFactory? factory,
    String? path,
    String fileName = localFileName,
    bool trackChanges = false,
    int Function()? clock,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), fileName);
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: 2, onCreate: _create, onUpgrade: _upgrade),
    );
    return SqliteLocalStore._(db, trackChanges, clock ?? () => DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch()
      ..execute('CREATE TABLE kv (key TEXT PRIMARY KEY, value TEXT NOT NULL)')
      ..execute(
        'CREATE TABLE meals (id TEXT PRIMARY KEY, logged_at INTEGER NOT NULL, json TEXT NOT NULL, '
        'updated_at INTEGER NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 0)',
      )
      ..execute('CREATE INDEX meals_logged_at ON meals (logged_at)')
      ..execute(
        'CREATE TABLE saved_foods (id TEXT PRIMARY KEY, created_at INTEGER NOT NULL, json TEXT NOT NULL, '
        'updated_at INTEGER NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 0)',
      )
      ..execute(
        'CREATE TABLE scan_feedback (id TEXT PRIMARY KEY, created_at INTEGER NOT NULL, json TEXT NOT NULL, '
        'updated_at INTEGER NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 0)',
      );
    _addV2Tables(batch);
    await batch.commit(noResult: true);
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 2) {
      final batch = db.batch();
      for (final table in _syncedTables.values) {
        batch
          ..execute('ALTER TABLE $table ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0')
          ..execute('ALTER TABLE $table ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0')
          ..execute('ALTER TABLE $table ADD COLUMN dirty INTEGER NOT NULL DEFAULT 0');
      }
      _addV2Tables(batch);
      await batch.commit(noResult: true);
    }
  }

  static void _addV2Tables(Batch batch) {
    batch
      ..execute('CREATE TABLE scan_drafts (id TEXT PRIMARY KEY, created_at INTEGER NOT NULL, json TEXT NOT NULL)')
      ..execute('CREATE TABLE sync_conflicts (id TEXT PRIMARY KEY, created_at INTEGER NOT NULL, json TEXT NOT NULL)')
      ..execute('CREATE TABLE health_writes (meal_id TEXT PRIMARY KEY, written_at INTEGER NOT NULL)');
  }

  @override
  Future<void> close() => _db.close();

  int get _dirtyFlag => tracksChanges ? 1 : 0;

  // ── key/value ──────────────────────────────────────────────────────────

  Future<String?> _readRaw(String key) async {
    final rows = await _db.query('kv', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> _writeRaw(String key, String? value) async {
    if (value == null) {
      await _db.delete('kv', where: 'key = ?', whereArgs: [key]);
    } else {
      await _db.insert('kv', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<Map<String, Object?>?> _readKv(String key) async {
    final raw = await _readRaw(key);
    return raw == null ? null : (jsonDecode(raw) as Map).cast<String, Object?>();
  }

  Future<void> _touchProfile() async {
    if (!tracksChanges) return;
    await _writeRaw(_profileUpdatedKey, '${_clock()}');
    await _writeRaw(_profileDirtyKey, '1');
  }

  @override
  Future<UserProfile?> loadProfile() async {
    final json = await _readKv(_profileKey);
    return json == null ? null : UserProfile.fromJson(json);
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _writeRaw(_profileKey, jsonEncode(profile.toJson()));
    await _touchProfile();
  }

  @override
  Future<void> clearProfile() async {
    await _writeRaw(_profileKey, null);
    await _touchProfile();
  }

  @override
  Future<AppSettings> loadSettings() async {
    final json = await _readKv(_settingsKey);
    return json == null ? const AppSettings() : AppSettings.fromJson(json);
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _writeRaw(_settingsKey, jsonEncode(settings.toJson()));
    await _touchProfile();
  }

  @override
  Future<String?> readMeta(String key) => _readRaw('$_metaPrefix$key');

  @override
  Future<void> writeMeta(String key, String? value) => _writeRaw('$_metaPrefix$key', value);

  // ── synced row helpers ─────────────────────────────────────────────────

  Future<void> _upsertRow(String table, String id, String sortColumn, int sortValue, Map<String, Object?> json) =>
      _db.insert(table, {
        'id': id,
        sortColumn: sortValue,
        'json': jsonEncode(json),
        'updated_at': _clock(),
        'deleted': 0,
        'dirty': _dirtyFlag,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> _deleteRow(String table, String id) async {
    if (tracksChanges) {
      await _db.update(table, {'deleted': 1, 'dirty': 1, 'updated_at': _clock()}, where: 'id = ?', whereArgs: [id]);
    } else {
      await _db.delete(table, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<List<Map<String, Object?>>> _live(String table, String orderBy) =>
      _db.query(table, where: 'deleted = 0', orderBy: orderBy);

  // ── meals ──────────────────────────────────────────────────────────────

  @override
  Future<List<Meal>> allMeals() async => [
    for (final r in await _live('meals', 'logged_at ASC')) Meal.fromJson(_decode(r)),
  ];

  @override
  Future<void> upsertMeal(Meal meal) =>
      _upsertRow('meals', meal.id, 'logged_at', meal.loggedAt.millisecondsSinceEpoch, meal.toJson());

  @override
  Future<void> deleteMeal(String id) => _deleteRow('meals', id);

  @override
  Future<void> deleteAllMeals() async {
    if (tracksChanges) {
      await _db.update('meals', {'deleted': 1, 'dirty': 1, 'updated_at': _clock()}, where: 'deleted = 0');
    } else {
      await _db.delete('meals');
    }
  }

  // ── saved foods ────────────────────────────────────────────────────────

  @override
  Future<List<SavedFood>> savedFoods() async => [
    for (final r in await _live('saved_foods', 'created_at DESC')) SavedFood.fromJson(_decode(r)),
  ];

  @override
  Future<void> addSavedFood(SavedFood food) =>
      _upsertRow('saved_foods', food.id, 'created_at', food.savedAt.millisecondsSinceEpoch, food.toJson());

  @override
  Future<void> deleteSavedFood(String id) => _deleteRow('saved_foods', id);

  // ── feedback ───────────────────────────────────────────────────────────

  @override
  Future<List<ScanFeedback>> feedback() async => [
    for (final r in await _live('scan_feedback', 'created_at DESC')) ScanFeedback.fromJson(_decode(r)),
  ];

  @override
  Future<void> addFeedback(ScanFeedback feedback) => _upsertRow(
    'scan_feedback',
    feedback.id,
    'created_at',
    feedback.createdAt.millisecondsSinceEpoch,
    feedback.toJson(),
  );

  // ── drafts / health writes (device only) ───────────────────────────────

  @override
  Future<List<ScanDraft>> scanDrafts() async => [
    for (final r in await _db.query('scan_drafts', orderBy: 'created_at DESC')) ScanDraft.fromJson(_decode(r)),
  ];

  @override
  Future<void> upsertDraft(ScanDraft draft) => _db.insert('scan_drafts', {
    'id': draft.id,
    'created_at': draft.createdAt.millisecondsSinceEpoch,
    'json': jsonEncode(draft.toJson()),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> deleteDraft(String id) => _db.delete('scan_drafts', where: 'id = ?', whereArgs: [id]);

  @override
  Future<bool> wasWrittenToHealth(String mealId) async =>
      (await _db.query('health_writes', where: 'meal_id = ?', whereArgs: [mealId], limit: 1)).isNotEmpty;

  @override
  Future<void> recordHealthWrite(String mealId) => _db.insert('health_writes', {
    'meal_id': mealId,
    'written_at': _clock(),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  // ── sync bookkeeping ───────────────────────────────────────────────────

  Future<SyncRecord?> _profileRecord({bool pendingOnly = false}) async {
    final dirty = await _readRaw(_profileDirtyKey) == '1';
    if (pendingOnly && !dirty) return null;
    final updated = int.tryParse(await _readRaw(_profileUpdatedKey) ?? '') ?? 0;
    return SyncRecord(
      entity: SyncEntity.profile,
      id: 'me',
      updatedAt: updated,
      pending: dirty,
      json: {'profile': await _readKv(_profileKey), 'settings': (await loadSettings()).toJson()},
    );
  }

  SyncRecord _rowRecord(SyncEntity entity, Map<String, Object?> r) => SyncRecord(
    entity: entity,
    id: r['id'] as String,
    updatedAt: r['updated_at'] as int,
    deleted: r['deleted'] == 1,
    pending: r['dirty'] == 1,
    json: r['deleted'] == 1 ? null : _decode(r),
  );

  @override
  Future<List<SyncRecord>> pendingRecords() async {
    if (!tracksChanges) return const [];
    final out = <SyncRecord>[?await _profileRecord(pendingOnly: true)];
    for (final MapEntry(key: entity, value: table) in _syncedTables.entries) {
      final rows = await _db.query(table, where: 'dirty = 1', orderBy: 'updated_at ASC');
      out.addAll(rows.map((r) => _rowRecord(entity, r)));
    }
    return out;
  }

  @override
  Future<int> pendingCount() async => (await pendingRecords()).length;

  @override
  Future<SyncRecord?> record(SyncEntity entity, String id) async {
    if (entity == SyncEntity.profile) return _profileRecord();
    final rows = await _db.query(_syncedTables[entity]!, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _rowRecord(entity, rows.first);
  }

  @override
  Future<void> markSynced(SyncRecord pushed) async {
    if (pushed.entity == SyncEntity.profile) {
      final updated = int.tryParse(await _readRaw(_profileUpdatedKey) ?? '') ?? 0;
      if (updated == pushed.updatedAt) await _writeRaw(_profileDirtyKey, null);
      return;
    }
    final table = _syncedTables[pushed.entity]!;
    if (pushed.deleted) {
      await _db.delete(
        table,
        where: 'id = ? AND deleted = 1 AND updated_at = ?',
        whereArgs: [pushed.id, pushed.updatedAt],
      );
    } else {
      await _db.update(
        table,
        {'dirty': 0},
        where: 'id = ? AND updated_at = ?',
        whereArgs: [pushed.id, pushed.updatedAt],
      );
    }
  }

  @override
  Future<void> applyRemote(SyncRecord remote) async {
    if (remote.entity == SyncEntity.profile) {
      final json = remote.json ?? const {};
      final profile = json['profile'];
      await _writeRaw(_profileKey, profile == null ? null : jsonEncode(profile));
      final settings = json['settings'];
      if (settings != null) await _writeRaw(_settingsKey, jsonEncode(settings));
      await _writeRaw(_profileUpdatedKey, '${remote.updatedAt}');
      await _writeRaw(_profileDirtyKey, null);
      return;
    }
    final table = _syncedTables[remote.entity]!;
    if (remote.deleted || remote.json == null) {
      await _db.delete(table, where: 'id = ?', whereArgs: [remote.id]);
      return;
    }
    final json = remote.json!;
    final (sortColumn, sortValue) = switch (remote.entity) {
      SyncEntity.meal => ('logged_at', json['loggedAt'] as int),
      SyncEntity.savedFood => ('created_at', json['savedAt'] as int),
      _ => ('created_at', json['createdAt'] as int),
    };
    await _db.insert(table, {
      'id': remote.id,
      sortColumn: sortValue,
      'json': jsonEncode(json),
      'updated_at': remote.updatedAt,
      'deleted': 0,
      'dirty': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<SyncConflict>> conflicts() async => [
    for (final r in await _db.query('sync_conflicts', orderBy: 'created_at DESC')) SyncConflict.fromJson(_decode(r)),
  ];

  @override
  Future<void> addConflict(SyncConflict conflict) => _db.insert('sync_conflicts', {
    'id': conflict.id,
    'created_at': conflict.createdAt.millisecondsSinceEpoch,
    'json': jsonEncode(conflict.toJson()),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> removeConflict(String id) => _db.delete('sync_conflicts', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> wipe() async {
    final batch = _db.batch();
    for (final table in [
      'kv',
      'meals',
      'saved_foods',
      'scan_feedback',
      'scan_drafts',
      'sync_conflicts',
      'health_writes',
    ]) {
      batch.delete(table);
    }
    await batch.commit(noResult: true);
  }

  static Map<String, Object?> _decode(Map<String, Object?> row) =>
      (jsonDecode(row['json'] as String) as Map).cast<String, Object?>();
}
