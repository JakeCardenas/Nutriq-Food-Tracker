import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/data/sync_engine.dart';
import 'package:nutriq/data/sync_models.dart';
import 'package:nutriq/domain/models/food_item.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/scan_draft.dart';
import 'package:nutriq/services/food_analysis/demo_food_analysis_service.dart';
import 'package:nutriq/services/food_analysis/food_analysis_service.dart';
import 'package:nutriq/state/scan_controller.dart';
import 'package:nutriq/state/sync_controller.dart';

import '../support/fake_cloud.dart';
import '../support/memory_local_store.dart';
import '../support/test_app.dart';

Meal _meal(String id, {String? name}) => Meal(
  id: id,
  loggedAt: DateTime(2026, 10, 6, 12),
  type: MealType.lunch,
  source: MealSource.manual,
  items: const [FoodItem(id: 'f', name: 'Rice', caloriesPerServing: 200)],
  name: name,
);

class _FlakyAnalysis implements FoodAnalysisService {
  bool fail = true;
  @override
  bool get isDemo => false;
  @override
  String get label => 'flaky';
  @override
  Future<FoodAnalysisResult> analyze(Uint8List imageBytes) async {
    if (fail) throw const FoodAnalysisException('timeout');
    return const FoodAnalysisResult(
      items: [FoodItem(id: 'x', name: 'Soup', caloriesPerServing: 150)],
      isDemo: false,
    );
  }
}

void main() {
  group('SyncController', () {
    late MemoryLocalStore store;
    late FakeCloud cloud;
    late SyncController sync;
    var pulledCalls = 0;
    var now = 1000;

    setUp(() {
      now = 1000;
      pulledCalls = 0;
      store = MemoryLocalStore(tracksChanges: true, clock: () => now);
      cloud = FakeCloud();
      sync = SyncController(
        engine: SyncEngine(store: store, cloud: cloud),
        store: store,
        onPulled: () async => pulledCalls++,
        debounce: Duration.zero,
      );
    });
    tearDown(() => sync.dispose());

    test('a successful sync reports synced with nothing pending', () async {
      await store.upsertMeal(_meal('a'));
      await sync.syncNow();
      expect(sync.state, SyncState.synced);
      expect(sync.pending, 0);
      expect(sync.lastSyncedAt, isNotNull);
    });

    test('offline keeps changes on the phone and says so', () async {
      cloud.offline = true;
      await store.upsertMeal(_meal('a'));
      await sync.syncNow();
      expect(sync.state, SyncState.offline);
      expect(sync.pending, 1);
      expect(sync.message, contains('saved on this phone'));
    });

    test('pulled changes trigger a reload of the screens', () async {
      cloud.serverWrite(SyncEntity.meal, 'b', _meal('b').toJson(), 5);
      await sync.syncNow();
      expect(pulledCalls, 1);
    });

    test('a conflict is counted and can be restored as a new local edit', () async {
      await store.upsertMeal(_meal('a'));
      await sync.syncNow();
      cloud.serverWrite(SyncEntity.meal, 'a', _meal('a', name: 'Newer').toJson(), 3000);
      now = 2000;
      await store.upsertMeal(_meal('a', name: 'Mine'));
      await sync.syncNow();
      expect(sync.conflicts.length, 1);

      now = 4000;
      await sync.restoreConflict(sync.conflicts.single);
      expect(sync.conflicts, isEmpty);
      expect((await store.allMeals()).single.name, 'Mine');
      await sync.syncNow();
      expect(Meal.fromJson(cloud.rows[SyncEntity.meal]!['a']!.json!).name, 'Mine');
    });

    test('server refusals surface as an error without losing the change', () async {
      cloud.rejectIds.add('a');
      await store.upsertMeal(_meal('a'));
      await sync.syncNow();
      expect(sync.state, SyncState.error);
      expect(sync.message, contains('couldn’t sync'));
      expect(sync.pending, 1);
    });
  });

  group('ScanController', () {
    late MemoryLocalStore store;
    late FakePhotoService photos;

    setUp(() {
      store = MemoryLocalStore();
      photos = FakePhotoService();
    });

    test('a scan becomes a persisted draft that turns ready for review', () async {
      final scans = ScanController(
        store: store,
        analysis: DemoFoodAnalysisService(delay: Duration.zero),
        photos: photos,
      );
      final draft = await scans.startScan('meal_photos/a.jpg');
      expect(draft.status, DraftStatus.analyzing);
      await scans.waitForIdle();
      final ready = scans.drafts.single;
      expect(ready.status, DraftStatus.ready);
      expect(ready.isDemo, isTrue);
      expect(ready.items, isNotEmpty);
      expect((await store.scanDrafts()).single.status, DraftStatus.ready);
    });

    test('a failed analysis keeps the photo and can be retried', () async {
      final analysis = _FlakyAnalysis();
      final scans = ScanController(store: store, analysis: analysis, photos: photos);
      await scans.startScan('meal_photos/a.jpg');
      await scans.waitForIdle();
      expect(scans.drafts.single.status, DraftStatus.failed);
      expect(scans.drafts.single.error, isNotNull);
      expect(photos.deleted, isEmpty);

      analysis.fail = false;
      await scans.retry(scans.drafts.single.id);
      await scans.waitForIdle();
      expect(scans.drafts.single.status, DraftStatus.ready);
      expect(scans.drafts.single.items.single.name, 'Soup');
    });

    test('drafts interrupted by closing the app come back as retryable', () async {
      await store.upsertDraft(
        ScanDraft(id: 'd', photoPath: 'p.jpg', createdAt: DateTime(2026), status: DraftStatus.analyzing),
      );
      final scans = ScanController(
        store: store,
        analysis: DemoFoodAnalysisService(delay: Duration.zero),
        photos: photos,
      );
      await scans.load();
      expect(scans.drafts.single.status, DraftStatus.failed);
      expect(scans.drafts.single.error, contains('interrupted'));
    });

    test('discarding removes the draft and its photo; logging keeps the photo', () async {
      final scans = ScanController(
        store: store,
        analysis: DemoFoodAnalysisService(delay: Duration.zero),
        photos: photos,
      );
      final a = await scans.startScan('p/a.jpg');
      final b = await scans.startScan('p/b.jpg');
      await scans.waitForIdle();
      await scans.discard(a.id);
      expect(photos.deleted, ['p/a.jpg']);
      await scans.markLogged(b.id);
      expect(photos.deleted, ['p/a.jpg']);
      expect(scans.drafts, isEmpty);
      expect(await store.scanDrafts(), isEmpty);
    });
  });
}
