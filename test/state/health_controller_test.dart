import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/food_item.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/services/health/health_service.dart';
import 'package:nutriq/state/health_controller.dart';

import '../support/fake_health.dart';
import '../support/memory_local_store.dart';

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
