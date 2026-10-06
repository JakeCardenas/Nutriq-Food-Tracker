import 'dart:io';

import 'package:health/health.dart' as hk;

import '../../domain/models/meal.dart';
import 'health_service.dart';

/// Apple Health via the `health` package (HealthKit). iOS only.
///
/// Reads: steps, workouts, active energy, body weight.
/// Writes (separate opt-in): one food entry per meal with dietary energy,
/// carbohydrates, protein and fat. No background delivery is requested.
class HealthKitService implements HealthService {
  HealthKitService() : _health = hk.Health();

  final hk.Health _health;
  bool _configured = false;

  static const readTypes = [
    hk.HealthDataType.STEPS,
    hk.HealthDataType.WORKOUT,
    hk.HealthDataType.ACTIVE_ENERGY_BURNED,
    hk.HealthDataType.WEIGHT,
  ];

  static const writeTypes = [
    hk.HealthDataType.DIETARY_ENERGY_CONSUMED,
    hk.HealthDataType.DIETARY_CARBS_CONSUMED,
    hk.HealthDataType.DIETARY_PROTEIN_CONSUMED,
    hk.HealthDataType.DIETARY_FATS_CONSUMED,
  ];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  bool get platformSupported => Platform.isIOS;

  @override
  Future<HealthAvailability> availability() async {
    if (!platformSupported) return HealthAvailability.unavailable;
    try {
      await _configure();
      return HealthAvailability.available;
    } catch (_) {
      return HealthAvailability.unavailable;
    }
  }

  @override
  Future<void> requestReadAccess() => _wrap(() async {
    await _configure();
    // Completing the request does not mean access was granted — HealthKit hides read permissions.
    await _health.requestAuthorization(readTypes, permissions: [for (final _ in readTypes) hk.HealthDataAccess.READ]);
  });

  @override
  Future<void> requestWriteAccess() => _wrap(() async {
    await _configure();
    await _health.requestAuthorization(
      writeTypes,
      permissions: [for (final _ in writeTypes) hk.HealthDataAccess.WRITE],
    );
  });

  @override
  Future<HealthSnapshot> readDay(DateTime start, DateTime end) => _wrap(() async {
    await _configure();
    final steps = await _health.getTotalStepsInInterval(start, end);

    final energyPoints = await _health.getHealthDataFromTypes(
      types: const [hk.HealthDataType.ACTIVE_ENERGY_BURNED],
      startTime: start,
      endTime: end,
    );
    final energy = _health.removeDuplicates(energyPoints).fold<double>(0, (sum, p) => sum + _numeric(p));

    final workoutPoints = await _health.getHealthDataFromTypes(
      types: const [hk.HealthDataType.WORKOUT],
      startTime: start.subtract(const Duration(days: 6)),
      endTime: end,
    );
    final workouts = [
      for (final p in workoutPoints)
        if (p.value is hk.WorkoutHealthValue)
          WorkoutSummary(
            activity: _activityName((p.value as hk.WorkoutHealthValue).workoutActivityType.name),
            start: p.dateFrom,
            duration: p.dateTo.difference(p.dateFrom),
            energyKcal: (p.value as hk.WorkoutHealthValue).totalEnergyBurned?.toDouble(),
          ),
    ]..sort((a, b) => b.start.compareTo(a.start));

    final weightPoints = await _health.getHealthDataFromTypes(
      types: const [hk.HealthDataType.WEIGHT],
      startTime: end.subtract(const Duration(days: 90)),
      endTime: end,
    );
    weightPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
    final latestWeight = weightPoints.isEmpty ? null : weightPoints.first;

    return HealthSnapshot(
      steps: steps,
      activeEnergyKcal: energyPoints.isEmpty ? null : energy,
      workouts: workouts,
      latestWeightKg: latestWeight == null ? null : _numeric(latestWeight),
      weightDate: latestWeight?.dateFrom,
    );
  });

  @override
  Future<bool> writeMeal(Meal meal) => _wrap(() async {
    await _configure();
    final t = meal.totals;
    return _health.writeMeal(
      mealType: switch (meal.type) {
        MealType.breakfast => hk.MealType.BREAKFAST,
        MealType.lunch => hk.MealType.LUNCH,
        MealType.dinner => hk.MealType.DINNER,
        MealType.snack => hk.MealType.SNACK,
      },
      startTime: meal.loggedAt,
      endTime: meal.loggedAt.add(const Duration(minutes: 1)),
      caloriesConsumed: t.calories,
      carbohydrates: t.carbs,
      protein: t.protein,
      fatTotal: t.fat,
      name: meal.title,
    );
  });

  static double _numeric(hk.HealthDataPoint p) =>
      p.value is hk.NumericHealthValue ? (p.value as hk.NumericHealthValue).numericValue.toDouble() : 0;

  static String _activityName(String raw) {
    final words = raw.toLowerCase().split('_').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'Workout';
    final first = words.first;
    return [first[0].toUpperCase() + first.substring(1), ...words.skip(1)].join(' ');
  }

  static Future<T> _wrap<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (e) {
      throw HealthServiceException('$e');
    }
  }
}
