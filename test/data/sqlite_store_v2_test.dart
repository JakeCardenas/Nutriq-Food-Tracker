import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/data/sqlite_local_store.dart';
import 'package:nutriq/data/sync_models.dart';
import 'package:nutriq/domain/models/food_item.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/scan_draft.dart';
import 'package:nutriq/domain/models/settings.dart';
import 'package:nutriq/domain/models/user_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _rice = FoodItem(id: 'f1', name: 'Rice', caloriesPerServing: 200);

Meal _meal(String id) => Meal(
  id: id,
  loggedAt: DateTime(2026, 10, 6, 12),
  type: MealType.lunch,
  source: MealSource.manual,
  items: const [_rice],
);

void main() {
  setUpAll(sqfliteFfiInit);
  var now = 1000;
  final opened = <SqliteLocalStore>[];
  tearDown(() async {
    for (final s in opened) {
      await s.close();
    }
    opened.clear();
  });

  Future<SqliteLocalStore> open({bool track = true}) async {
    final store = await SqliteLocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      trackChanges: track,
      clock: () => now,
    );
    opened.add(store);
    return store;
  }

  test('a v1 database from the MVP is upgraded without losing meals', () async {
    final dir = await Directory.systemTemp.createTemp('nutriq_v1');
    final path = '${dir.path}/nutriq.db';
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('CREATE TABLE kv (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
          await db.execute('CREATE TABLE meals (id TEXT PRIMARY KEY, logged_at INTEGER NOT NULL, json TEXT NOT NULL)');
          await db.execute(
            'CREATE TABLE saved_foods (id TEXT PRIMARY KEY, created_at INTEGER NOT NULL, json TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE scan_feedback (id TEXT PRIMARY KEY, created_at INTEGER NOT NULL, json TEXT NOT NULL)',
          );
        },
      ),
    );
    await v1.insert('meals', {'id': 'old', 'logged_at': 1, 'json': jsonEncode(_meal('old').toJson())});
    await v1.insert('kv', {'key': 'profile', 'value': jsonEncode(const UserProfile(age: 33).toJson())});
    await v1.close();

    final store = await SqliteLocalStore.open(factory: databaseFactoryFfi, path: path);
    expect((await store.allMeals()).single.id, 'old');
    expect((await store.loadProfile())!.age, 33);
    expect(await store.scanDrafts(), isEmpty);
    await store.close();
    await dir.delete(recursive: true);
  });

  group('account store (tracks changes)', () {
    test('edits become pending records', () async {
      final store = await open();
      await store.upsertMeal(_meal('a'));
      final pending = await store.pendingRecords();
      expect(pending.single.entity, SyncEntity.meal);
      expect(pending.single.updatedAt, 1000);
      expect(await store.pendingCount(), 1);
    });

    test('deleting leaves a hidden tombstone until it is synced', () async {
      final store = await open();
      await store.upsertMeal(_meal('a'));
      await store.markSynced((await store.pendingRecords()).single);
      now = 2000;
      await store.deleteMeal('a');
      expect(await store.allMeals(), isEmpty);
      final tomb = (await store.pendingRecords()).single;
      expect(tomb.deleted, isTrue);
      await store.markSynced(tomb);
      expect(await store.pendingRecords(), isEmpty);
      expect(await store.record(SyncEntity.meal, 'a'), isNull);
    });

    test('markSynced keeps a row pending if it was edited after the push started', () async {
      now = 1000;
      final store = await open();
      await store.upsertMeal(_meal('a'));
      final pushed = (await store.pendingRecords()).single;
      now = 1500;
      await store.upsertMeal(_meal('a').copyWith(name: 'Edited'));
      await store.markSynced(pushed);
      expect((await store.pendingRecords()).single.updatedAt, 1500);
    });

    test('remote changes apply without becoming pending, and remote deletes remove the row', () async {
      final store = await open();
      await store.applyRemote(SyncRecord(entity: SyncEntity.meal, id: 'r', updatedAt: 5, json: _meal('r').toJson()));
      expect((await store.allMeals()).single.id, 'r');
      expect(await store.pendingRecords(), isEmpty);
      await store.applyRemote(const SyncRecord(entity: SyncEntity.meal, id: 'r', updatedAt: 6, deleted: true));
      expect(await store.allMeals(), isEmpty);
    });

    test('profile and settings travel together as one record', () async {
      final store = await open();
      await store.saveProfile(const UserProfile(age: 40));
      await store.saveSettings(const AppSettings(dayStartHour: 4, onboardingComplete: true));
      final rec = (await store.pendingRecords()).single;
      expect(rec.entity, SyncEntity.profile);
      expect((rec.json!['profile'] as Map)['age'], 40);
      expect((rec.json!['settings'] as Map)['dayStartHour'], 4);

      await store.markSynced(rec);
      await store.applyRemote(
        SyncRecord(
          entity: SyncEntity.profile,
          id: 'me',
          updatedAt: 9,
          json: {'profile': const UserProfile(age: 41).toJson(), 'settings': const AppSettings().toJson()},
        ),
      );
      expect((await store.loadProfile())!.age, 41);
      expect(await store.pendingRecords(), isEmpty);
    });

    test('conflicts are stored and removable', () async {
      final store = await open();
      final c = SyncConflict(
        id: 'c1',
        entity: SyncEntity.meal,
        entityId: 'a',
        createdAt: DateTime(2026),
        summary: 'Lunch',
        discardedJson: _meal('a').toJson(),
      );
      await store.addConflict(c);
      expect((await store.conflicts()).single.summary, 'Lunch');
      await store.removeConflict('c1');
      expect(await store.conflicts(), isEmpty);
    });
  });

  group('local-only store', () {
    test('deletes are permanent and nothing is pending', () async {
      final store = await open(track: false);
      await store.upsertMeal(_meal('a'));
      await store.deleteMeal('a');
      expect(await store.pendingRecords(), isEmpty);
      expect(await store.record(SyncEntity.meal, 'a'), isNull);
    });
  });

  test('drafts, metadata and Apple Health write records persist', () async {
    final store = await open();
    final draft = ScanDraft(
      id: 'd1',
      photoPath: 'p.jpg',
      createdAt: DateTime(2026, 10, 6),
      status: DraftStatus.ready,
      items: const [_rice],
      isDemo: true,
    );
    await store.upsertDraft(draft);
    expect((await store.scanDrafts()).single.items.single.name, 'Rice');
    await store.deleteDraft('d1');
    expect(await store.scanDrafts(), isEmpty);

    await store.writeMeta('k', 'v');
    expect(await store.readMeta('k'), 'v');
    await store.writeMeta('k', null);
    expect(await store.readMeta('k'), isNull);

    expect(await store.wasWrittenToHealth('m1'), isFalse);
    await store.recordHealthWrite('m1');
    expect(await store.wasWrittenToHealth('m1'), isTrue);
  });
}
