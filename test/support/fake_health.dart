import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/services/health/health_service.dart';

/// Scriptable Apple Health stand-in. Tests never touch real HealthKit.
class FakeHealthService implements HealthService {
  FakeHealthService({this.platformSupported = true});

  @override
  final bool platformSupported;
  HealthAvailability availabilityResult = HealthAvailability.available;
  bool throwOnRequest = false;
  HealthSnapshot snapshot = const HealthSnapshot();
  final written = <String>[];
  int readRequests = 0;
  int writeRequests = 0;

  @override
  Future<HealthAvailability> availability() async => availabilityResult;
  @override
  Future<void> requestReadAccess() async {
    readRequests++;
    if (throwOnRequest) throw const HealthServiceException('HealthKit not available');
  }

  @override
  Future<void> requestWriteAccess() async {
    writeRequests++;
    if (throwOnRequest) throw const HealthServiceException('HealthKit not available');
  }

  @override
  Future<HealthSnapshot> readDay(DateTime start, DateTime end) async => snapshot;
  @override
  Future<bool> writeMeal(Meal meal) async {
    written.add(meal.id);
    return true;
  }
}
