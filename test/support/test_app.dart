import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/app/app_scope.dart';
import 'package:nutriq/app/nutriq_app.dart';
import 'package:nutriq/app/session.dart';
import 'package:nutriq/app/theme.dart';
import 'package:nutriq/data/cloud_repository.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/settings.dart';
import 'package:nutriq/domain/models/user_profile.dart';
import 'package:nutriq/services/auth/auth_service.dart';
import 'package:nutriq/services/coach/demo_coach_service.dart';
import 'package:nutriq/services/food_analysis/demo_food_analysis_service.dart';
import 'package:nutriq/services/food_analysis/food_analysis_service.dart';
import 'package:nutriq/services/health/health_service.dart';
import 'package:nutriq/services/photo_service.dart';
import 'package:nutriq/state/coach_controller.dart';
import 'package:nutriq/state/health_controller.dart';
import 'package:nutriq/state/meal_log_controller.dart';
import 'package:nutriq/state/profile_controller.dart';
import 'package:nutriq/state/scan_controller.dart';
import 'package:nutriq/state/session_controller.dart';

import 'memory_local_store.dart';

/// Photo service whose next pick result is set by the test.
class FakePhotoService implements PhotoService {
  PhotoPickResult next = const PhotoPicked('/fake/photo.jpg');
  final deleted = <String>[];
  bool deletedAll = false;

  @override
  Future<PhotoPickResult> pick(PhotoSource source) async => next;
  @override
  Future<String> persist(String tempPath) async => 'meal_photos/test.jpg';
  @override
  File resolve(String storedPath) => File('/nonexistent/$storedPath');
  @override
  Future<Uint8List> readBytes(String storedPath) async => Uint8List.fromList(List.filled(64, 7));
  @override
  Future<void> delete(String storedPath) async => deleted.add(storedPath);
  @override
  Future<void> deleteAll() async => deletedAll = true;
  @override
  Future<String?> importFile(File source) async => 'imported/${source.path.split('/').last}';
}

/// A real [SessionController] around an in-memory store, for widget tests.
class TestDeps {
  TestDeps._(this.sessions, this.auth, this.photos);

  final SessionController sessions;
  final AuthService auth;
  final FakePhotoService photos;

  AppSession get session => sessions.session!;
  MemoryLocalStore get store => session.store as MemoryLocalStore;
  ProfileController get profile => session.profile;
  MealLogController get log => session.log;
  CoachController get coach => session.coach;
  ScanController get scans => session.scans;
  HealthController get health => session.health;
  FoodAnalysisService get analysis => session.analysis;

  static Future<TestDeps> create({
    UserProfile? profile,
    AppSettings settings = const AppSettings(onboardingComplete: true),
    List<Meal>? meals,
    FoodAnalysisService? analysis,
    HealthService? health,
    AuthService? auth,
    CloudRepository? cloud,
  }) async {
    final store = MemoryLocalStore(profile: profile, settings: settings, meals: meals);
    final photos = FakePhotoService();
    final services = SessionServices(
      analysis: analysis ?? DemoFoodAnalysisService(delay: Duration.zero),
      coach: DemoCoachService(replyDelay: Duration.zero),
      health: health ?? const UnsupportedHealthService(),
    );
    final authService = auth ?? const DisabledAuthService();
    final sessions = SessionController(
      auth: authService,
      buildSession: (user) => assembleSession(
        user: user,
        store: store,
        photos: photos,
        cloud: user == null ? null : cloud,
        services: services,
        syncDebounce: Duration.zero,
      ),
      openLocalStore: () async => store,
      localPhotos: photos,
    );
    await sessions.start();
    return TestDeps._(sessions, authService, photos);
  }

  Widget wrap(Widget child) => AppScope(sessions: sessions, session: session, auth: auth, child: child);

  /// Pumps the whole app (onboarding or the home shell).
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(NutriqApp(sessions: sessions, auth: auth));
    await tester.pumpAndSettle();
  }

  /// Pumps [screen] pushed on top of a host page so it can pop.
  Future<void> pumpPushed(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      wrap(
        MaterialApp(
          theme: buildNutriqTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<Object?>(builder: (_) => screen)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}
