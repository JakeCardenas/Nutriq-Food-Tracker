import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/models/meal.dart';
import '../domain/models/saved_food.dart';
import '../domain/models/scan_feedback.dart';
import '../domain/models/settings.dart';
import '../domain/models/user_profile.dart';
import 'local_store.dart';

/// SQLite-backed [LocalStore]. Rows hold a JSON document plus the columns we
/// sort by, which keeps schema changes cheap while the models evolve.
class SqliteLocalStore implements LocalStore {
  SqliteLocalStore._(this._db);

  final Database _db;

  static const _profileKey = 'profile';
  static const _settingsKey = 'settings';

  /// Opens (or creates) the database. Pass [factory]/[path] in tests.
  static Future<SqliteLocalStore> open({DatabaseFactory? factory, String? path}) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), 'nutriq.db');
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: 1, onCreate: _create),
    );
    return SqliteLocalStore._(db);
  }

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch()
      ..execute('CREATE TABLE kv (key TEXT PRIMARY KEY, value TEXT NOT NULL)')
      ..execute('CREATE TABLE meals (id TEXT PRIMARY KEY, logged_at INTEGER NOT NULL, json TEXT NOT NULL)')
      ..execute('CREATE INDEX meals_logged_at ON meals (logged_at)')
      ..execute(
        'CREATE TABLE saved_foods (id TEXT PRIMARY KEY, created_at INTEGER NOT NULL, json TEXT NOT NULL)',
      )
      ..execute(
        'CREATE TABLE scan_feedback (id TEXT PRIMARY KEY, created_at INTEGER NOT NULL, json TEXT NOT NULL)',
      );
    await batch.commit(noResult: true);
  }

  Future<void> close() => _db.close();

  // ── key/value ──────────────────────────────────────────────────────────

  Future<Map<String, Object?>?> _readKv(String key) async {
    final rows = await _db.query('kv', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return (jsonDecode(rows.first['value'] as String) as Map).cast<String, Object?>();
  }

  Future<void> _writeKv(String key, Map<String, Object?> value) => _db.insert('kv', {
    'key': key,
    'value': jsonEncode(value),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<UserProfile?> loadProfile() async {
    final json = await _readKv(_profileKey);
    return json == null ? null : UserProfile.fromJson(json);
  }

  @override
  Future<void> saveProfile(UserProfile profile) => _writeKv(_profileKey, profile.toJson());

  @override
  Future<void> clearProfile() => _db.delete('kv', where: 'key = ?', whereArgs: [_profileKey]);

  @override
  Future<AppSettings> loadSettings() async {
    final json = await _readKv(_settingsKey);
    return json == null ? const AppSettings() : AppSettings.fromJson(json);
  }

  @override
  Future<void> saveSettings(AppSettings settings) => _writeKv(_settingsKey, settings.toJson());

  // ── meals ──────────────────────────────────────────────────────────────

  @override
  Future<List<Meal>> allMeals() async {
    final rows = await _db.query('meals', orderBy: 'logged_at ASC');
    return [for (final r in rows) Meal.fromJson(_decode(r))];
  }

  @override
  Future<void> upsertMeal(Meal meal) => _db.insert('meals', {
    'id': meal.id,
    'logged_at': meal.loggedAt.millisecondsSinceEpoch,
    'json': jsonEncode(meal.toJson()),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> deleteMeal(String id) => _db.delete('meals', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> deleteAllMeals() => _db.delete('meals');

  // ── saved foods ────────────────────────────────────────────────────────

  @override
  Future<List<SavedFood>> savedFoods() async {
    final rows = await _db.query('saved_foods', orderBy: 'created_at DESC');
    return [for (final r in rows) SavedFood.fromJson(_decode(r))];
  }

  @override
  Future<void> addSavedFood(SavedFood food) => _db.insert('saved_foods', {
    'id': food.id,
    'created_at': food.savedAt.millisecondsSinceEpoch,
    'json': jsonEncode(food.toJson()),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> deleteSavedFood(String id) => _db.delete('saved_foods', where: 'id = ?', whereArgs: [id]);

  // ── feedback ───────────────────────────────────────────────────────────

  @override
  Future<List<ScanFeedback>> feedback() async {
    final rows = await _db.query('scan_feedback', orderBy: 'created_at DESC');
    return [for (final r in rows) ScanFeedback.fromJson(_decode(r))];
  }

  @override
  Future<void> addFeedback(ScanFeedback feedback) => _db.insert('scan_feedback', {
    'id': feedback.id,
    'created_at': feedback.createdAt.millisecondsSinceEpoch,
    'json': jsonEncode(feedback.toJson()),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> wipe() async {
    final batch = _db.batch()
      ..delete('kv')
      ..delete('meals')
      ..delete('saved_foods')
      ..delete('scan_feedback');
    await batch.commit(noResult: true);
  }

  static Map<String, Object?> _decode(Map<String, Object?> row) =>
      (jsonDecode(row['json'] as String) as Map).cast<String, Object?>();
}
