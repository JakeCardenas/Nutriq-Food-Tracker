import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/data/cloud_repository.dart';
import 'package:nutriq/data/local_data_importer.dart';
import 'package:nutriq/data/sqlite_local_store.dart';
import 'package:nutriq/data/sync_engine.dart';
import 'package:nutriq/data/sync_models.dart';
import 'package:nutriq/domain/models/food_item.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/saved_food.dart';
import 'package:nutriq/domain/models/settings.dart';
import 'package:nutriq/domain/models/user_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/fake_cloud.dart';

const _rice = FoodItem(id: 'f1', name: 'Rice', caloriesPerServing: 200);

Meal _meal(String id, {String? name, String? photo}) => Meal(
  id: id,
  loggedAt: DateTime(2026, 10, 6, 12),
  type: MealType.lunch,
  source: MealSource.manual,
  items: const [_rice],
  name: name,
  photoPath: photo,
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

  var counter = 0;
  final tempDir = Directory.systemTemp.createTempSync('nutriq_sync');
  tearDownAll(() => tempDir.deleteSync(recursive: true));

  Future<SqliteLocalStore> store({bool track = true}) async {
    final s = await SqliteLocalStore.open(
      factory: databaseFactoryFfi,
      path: '${tempDir.path}/store${counter++}.db',
      trackChanges: track,
      clock: () => now,
    );
    opened.add(s);
    return s;
  }

  group('SyncEngine', () {
    test('pushes pending changes once and marks them synced', () async {
      now = 1000;
      final local = await store();
      final cloud = FakeCloud();
      final removed = <String>[];
      final engine = SyncEngine(store: local, cloud: cloud, onMealPhotoOrphaned: removed.add);
      await local.upsertMeal(_meal('a'));
      await local.saveProfile(const UserProfile(age: 30));

      final report = await engine.sync();
      expect(report.pushed, 2);
      expect(cloud.count(SyncEntity.meal), 1);
      expect(await local.pendingCount(), 0);

      final again = await engine.sync();
      expect(again.pushed, 0, reason: 'no duplicate uploads');
      expect(cloud.count(SyncEntity.meal), 1);
    });

    test('offline keeps changes pending and reports offline', () async {
      final local = await store();
      final cloud = FakeCloud()..offline = true;
      final engine = SyncEngine(store: local, cloud: cloud);
      await local.upsertMeal(_meal('a'));
      await expectLater(engine.sync(), throwsA(isA<CloudOfflineException>()));
      expect(await local.pendingCount(), 1);

      cloud.offline = false;
      await engine.sync();
      expect(await local.pendingCount(), 0);
      expect(cloud.count(SyncEntity.meal), 1);
    });

    test('pulls changes from other devices and keeps this phone\'s photo link', () async {
      final local = await store();
      final cloud = FakeCloud();
      final engine = SyncEngine(store: local, cloud: cloud);
      await local.upsertMeal(_meal('a', photo: 'accounts/u/meal_photos/a.jpg'));
      await engine.sync();

      cloud.serverWrite(
        SyncEntity.meal,
        'a',
        _meal('a', name: 'Renamed elsewhere').toJson()..remove('photoPath'),
        5000,
      );
      cloud.serverWrite(SyncEntity.meal, 'b', _meal('b').toJson(), 5001);
      final report = await engine.sync();
      expect(report.pulled, 2);
      final meals = await local.allMeals();
      expect(meals.map((m) => m.id), containsAll(['a', 'b']));
      final a = meals.firstWhere((m) => m.id == 'a');
      expect(a.name, 'Renamed elsewhere');
      expect(a.photoPath, 'accounts/u/meal_photos/a.jpg');
      expect(await local.pendingCount(), 0);
    });

    test('a deletion on another device removes the meal and its photo here', () async {
      final local = await store();
      final cloud = FakeCloud();
      final orphaned = <String>[];
      final engine = SyncEngine(store: local, cloud: cloud, onMealPhotoOrphaned: orphaned.add);
      await local.upsertMeal(_meal('a', photo: 'p/a.jpg'));
      await engine.sync();
      cloud.serverWrite(SyncEntity.meal, 'a', null, 9000, deleted: true);
      await engine.sync();
      expect(await local.allMeals(), isEmpty);
      expect(orphaned, ['p/a.jpg']);
    });

    test('a stale edit loses to a newer one but is kept as a visible conflict', () async {
      now = 1000;
      final local = await store();
      final cloud = FakeCloud();
      final engine = SyncEngine(store: local, cloud: cloud);
      await local.upsertMeal(_meal('a'));
      await engine.sync();

      // Another device edits later; this phone edits offline with an older clock.
      cloud.serverWrite(SyncEntity.meal, 'a', _meal('a', name: 'Newer elsewhere').toJson(), 3000);
      now = 2000;
      await local.upsertMeal(_meal('a', name: 'Older here'));

      final report = await engine.sync();
      expect(report.conflicts, 1);
      expect((await local.allMeals()).single.name, 'Newer elsewhere');
      final conflict = (await local.conflicts()).single;
      expect(conflict.discardedJson!['name'], 'Older here');
      expect(conflict.summary, contains('Older here'));
      expect(await local.pendingCount(), 0);
    });

    test('a rejected record is reported and stays pending without blocking others', () async {
      final local = await store();
      final cloud = FakeCloud()..rejectIds.add('bad');
      final engine = SyncEngine(store: local, cloud: cloud);
      await local.upsertMeal(_meal('bad'));
      await local.upsertMeal(_meal('good'));
      final report = await engine.sync();
      expect(report.rejected.single, contains('Value out of range'));
      expect(cloud.count(SyncEntity.meal), 1);
      expect((await local.pendingRecords()).single.id, 'bad');
    });

    test('profile and settings arrive on a new device', () async {
      final cloud = FakeCloud()
        ..serverWrite(SyncEntity.profile, 'me', {
          'profile': const UserProfile(age: 44).toJson(),
          'settings': const AppSettings(onboardingComplete: true, dayStartHour: 3).toJson(),
        }, 10);
      final local = await store();
      await SyncEngine(store: local, cloud: cloud).sync();
      expect((await local.loadProfile())!.age, 44);
      expect((await local.loadSettings()).onboardingComplete, isTrue);
    });
  });

  group('LocalDataImporter', () {
    test('copies local-only data into the account as pending uploads, once', () async {
      now = 1000;
      final source = await store(track: false);
      await source.saveProfile(const UserProfile(age: 30));
      await source.saveSettings(const AppSettings(onboardingComplete: true));
      await source.upsertMeal(_meal('m1', photo: 'meal_photos/m1.jpg'));
      await source.addSavedFood(SavedFood(id: 's1', item: _rice, savedAt: DateTime(2026)));
      final target = await store();
      final copied = <String>[];

      final summary = await LocalDataImporter.summarize(source, userId: 'u1');
      expect(summary.meals, 1);
      expect(summary.savedFoods, 1);
      expect(summary.hasProfile, isTrue);
      expect(summary.alreadyImported, isFalse);

      final result = await LocalDataImporter.importInto(
        source: source,
        target: target,
        userId: 'u1',
        copyPhoto: (path) async {
          copied.add(path);
          return 'accounts/u1/$path';
        },
      );
      expect(result.meals, 1);
      expect((await target.allMeals()).single.photoPath, 'accounts/u1/meal_photos/m1.jpg');
      expect(copied, ['meal_photos/m1.jpg']);
      expect((await target.loadProfile())!.age, 30);
      expect(await target.pendingCount(), 3, reason: 'profile + meal + saved food');
      expect((await source.allMeals()).single.id, 'm1', reason: 'local data is never erased by import');

      expect((await LocalDataImporter.summarize(source, userId: 'u1')).alreadyImported, isTrue);
      final second = await LocalDataImporter.importInto(
        source: source,
        target: target,
        userId: 'u1',
        copyPhoto: (p) async => p,
      );
      expect(second.meals, 0);
      expect((await target.allMeals()).length, 1);
    });

    test('an existing account profile is kept rather than overwritten', () async {
      final source = await store(track: false);
      await source.saveProfile(const UserProfile(age: 30));
      final target = await store();
      await target.saveProfile(const UserProfile(age: 50));
      final result = await LocalDataImporter.importInto(
        source: source,
        target: target,
        userId: 'u2',
        copyPhoto: (p) async => p,
      );
      expect(result.profileKept, isTrue);
      expect((await target.loadProfile())!.age, 50);
    });
  });
}
