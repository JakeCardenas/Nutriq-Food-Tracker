import '../../domain/models/meal.dart';

enum HealthAvailability { available, unavailable }

class WorkoutSummary {
  const WorkoutSummary({required this.activity, required this.start, required this.duration, this.energyKcal});
  final String activity;
  final DateTime start;
  final Duration duration;
  final double? energyKcal;
}

/// What Nutriq reads from Apple Health for one day. Stays on the device.
class HealthSnapshot {
  const HealthSnapshot({
    this.steps,
    this.activeEnergyKcal,
    this.workouts = const [],
    this.latestWeightKg,
    this.weightDate,
  });

  final int? steps;
  final double? activeEnergyKcal;
  final List<WorkoutSummary> workouts;
  final double? latestWeightKg;
  final DateTime? weightDate;

  bool get isEmpty =>
      (steps == null || steps == 0) &&
      (activeEnergyKcal == null || activeEnergyKcal == 0) &&
      workouts.isEmpty &&
      latestWeightKg == null;
}

class HealthServiceException implements Exception {
  const HealthServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Apple Health access. iOS only in this version (Android Health Connect is a
/// separate integration and is not implemented).
///
/// Note on permissions: HealthKit never tells apps whether *read* access was
/// granted. A request that completes and then returns no data may mean "no
/// data yet" or "not allowed" — the UI must not claim the user denied access.
abstract interface class HealthService {
  bool get platformSupported;
  Future<HealthAvailability> availability();

  /// Shows the HealthKit sheet for steps, workouts, active energy and body weight.
  Future<void> requestReadAccess();

  /// Shows the HealthKit sheet for writing dietary energy and macros.
  Future<void> requestWriteAccess();

  Future<HealthSnapshot> readDay(DateTime start, DateTime end);

  /// Writes one food entry (calories + macros) for [meal]. Returns false if HealthKit refused it.
  Future<bool> writeMeal(Meal meal);

  /// Deletes the nutrition Nutriq wrote for [meal] (matched by its exact logged time). Only Nutriq's
  /// own samples can be deleted. Returns false if HealthKit refused.
  Future<bool> deleteMeal(Meal meal);
}

class UnsupportedHealthService implements HealthService {
  const UnsupportedHealthService();
  @override
  bool get platformSupported => false;
  @override
  Future<HealthAvailability> availability() async => HealthAvailability.unavailable;
  @override
  Future<void> requestReadAccess() async {}
  @override
  Future<void> requestWriteAccess() async {}
  @override
  Future<HealthSnapshot> readDay(DateTime start, DateTime end) async => const HealthSnapshot();
  @override
  Future<bool> writeMeal(Meal meal) async => false;

  @override
  Future<bool> deleteMeal(Meal meal) async => false;
}
