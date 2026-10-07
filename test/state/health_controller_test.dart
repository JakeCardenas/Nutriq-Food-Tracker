import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/food_item.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/services/health/health_service.dart';
import 'package:nutriq/state/health_controller.dart';

import '../support/fake_health.dart';
import '../support/memory_local_store.dart';
import '../support/test_app.dart';

final _meal = Meal(
  id: 'm1',
  loggedAt: DateTime(2026, 10, 6, 12),
  type: MealType.lunch,
  source: MealSource.manual,
  items: const [FoodItem(id: 'f', name: 'Rice', caloriesPerServing: 200, carbsPerServing: 45)],
);

void main() {
  late MemoryLocalStore store;
  setUp(() => store = MemoryLocalStore());

  test('Apple Health is unavailable off iPhone and never prompts', () async {
    final service = FakeHealthService(platformSupported: false);
    final health = HealthController(service: service, store: store);
    await health.load();
    expect(health.status, HealthStatus.unsupported);
    await health.connect();
    expect(service.readRequests, 0);
  });

  test('no permission prompt until the person turns it on', () async {
    final service = FakeHealthService();
    final health = HealthController(service: service, store: store);
    await health.load();
    expect(health.status, HealthStatus.off);
    expect(service.readRequests, 0);
  });

  test('connecting reads today’s activity and remembers the choice', () async {
    final service = FakeHealthService()
      ..snapshot = const HealthSnapshot(steps: 8200, activeEnergyKcal: 410, latestWeightKg: 80.2);
    final health = HealthController(service: service, store: store);
    await health.load();
    await health.connect();
    expect(health.status, HealthStatus.connected);
    expect(health.today!.steps, 8200);
    expect(await store.readMeta('health:read'), '1');

    final reopened = HealthController(service: service, store: store);
    await reopened.load();
    expect(reopened.status, HealthStatus.connected);
  });

  test('no data is reported as "no data found", not as a denial', () async {
    final health = HealthController(service: FakeHealthService(), store: store);
    await health.connect();
    expect(health.status, HealthStatus.connected);
    expect(health.message, contains('No Apple Health data'));
    expect(health.message!.toLowerCase(), isNot(contains('denied')));
  });

  test('HealthKit errors are reported without breaking anything', () async {
    final service = FakeHealthService()..throwOnRequest = true;
    final health = HealthController(service: service, store: store);
    await health.connect();
    expect(health.status, HealthStatus.error);
    expect(health.message, contains('HealthKit not available'));
    expect(await store.readMeta('health:read'), isNull);
  });

  test('a device without Health data store reports unavailable', () async {
    final service = FakeHealthService()..availabilityResult = HealthAvailability.unavailable;
    final health = HealthController(service: service, store: store);
    await health.load();
    expect(health.status, HealthStatus.unsupported);
  });

  test('nutrition is written once per meal, only when opted in', () async {
    final service = FakeHealthService();
    final health = HealthController(service: service, store: store);
    await health.connect();
    await health.onMealSaved(_meal);
    expect(service.written, isEmpty, reason: 'writing is a separate opt-in');

    await health.setWriteEnabled(true);
    expect(service.writeRequests, 1);
    await health.onMealSaved(_meal);
    await health.onMealSaved(_meal.copyWith(name: 'edited'));
    expect(service.written, ['m1'], reason: 'never duplicated');
  });

  group('a meal already in Apple Health', () {
    late FakeHealthService service;
    late HealthController health;
    setUp(() async {
      service = FakeHealthService();
      health = HealthController(service: service, store: store);
      await health.connect();
      await health.setWriteEnabled(true);
      await health.onMealSaved(_meal);
    });

    test('changing its amounts replaces it there — no double counting', () async {
      final more = _meal.copyWith(items: [_meal.items.single.copyWith(servings: 2)]);
      await health.onMealSaved(more, previous: _meal);
      expect(service.deleted, [('m1', _meal.loggedAt)]);
      expect(service.written, ['m1', 'm1']);
    });

    test('moving it to another time deletes it at its old time', () async {
      final later = _meal.copyWith(loggedAt: DateTime(2026, 10, 6, 19));
      await health.onMealSaved(later, previous: _meal);
      expect(service.deleted, [('m1', DateTime(2026, 10, 6, 12))]);
      expect(service.written, ['m1', 'm1']);
    });

    test('a rename alone leaves Apple Health as it is', () async {
      await health.onMealSaved(_meal.copyWith(name: 'Rice bowl'), previous: _meal);
      expect(service.deleted, isEmpty);
      expect(service.written, ['m1']);
    });

    test('deleting the meal removes it from Apple Health', () async {
      await health.onMealDeleted(_meal);
      expect(service.deleted, [('m1', _meal.loggedAt)]);
      Meal other(String id) =>
          Meal(id: id, loggedAt: _meal.loggedAt, type: _meal.type, source: _meal.source, items: _meal.items);
      await health.onMealDeleted(other('m9'));
      expect(service.deleted, hasLength(1), reason: 'a meal never written isn’t touched');
    });

    test('if Apple Health refuses the delete, nothing is written twice and the person is told', () async {
      service.deleteSucceeds = false;
      final more = _meal.copyWith(items: [_meal.items.single.copyWith(servings: 2)]);
      await health.onMealSaved(more, previous: _meal);
      expect(service.written, ['m1']);
      expect(health.message, contains('Apple Health'));
    });
  });

  test('in the app, logging, editing and deleting a meal keep Apple Health in step', () async {
    final service = FakeHealthService();
    final deps = await TestDeps.create(health: service);
    await deps.health.connect();
    await deps.health.setWriteEnabled(true);

    await deps.log.saveMeal(_meal);
    await Future<void>.delayed(Duration.zero);
    await deps.log.saveMeal(_meal.copyWith(items: [_meal.items.single.copyWith(servings: 3)]));
    await Future<void>.delayed(Duration.zero);
    await deps.log.deleteMeal(_meal);
    await Future<void>.delayed(Duration.zero);

    expect(service.written, ['m1', 'm1']);
    expect(service.deleted.map((d) => d.$1), ['m1', 'm1']);
  });

  test('disconnecting stops reading and writing on this phone', () async {
    final service = FakeHealthService()..snapshot = const HealthSnapshot(steps: 10);
    final health = HealthController(service: service, store: store);
    await health.connect();
    await health.setWriteEnabled(true);
    await health.disconnect();
    expect(health.status, HealthStatus.off);
    expect(health.today, isNull);
    expect(health.writeEnabled, isFalse);
    await health.onMealSaved(_meal);
    expect(service.written, isEmpty);
  });
}
