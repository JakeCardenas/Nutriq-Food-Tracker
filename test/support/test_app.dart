import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/app/app_scope.dart';
import 'package:nutriq/app/theme.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/settings.dart';
import 'package:nutriq/domain/models/user_profile.dart';
import 'package:nutriq/services/coach/demo_coach_service.dart';
import 'package:nutriq/services/food_analysis/demo_food_analysis_service.dart';
import 'package:nutriq/services/food_analysis/food_analysis_service.dart';
import 'package:nutriq/services/photo_service.dart';
import 'package:nutriq/state/coach_controller.dart';
import 'package:nutriq/state/meal_log_controller.dart';
import 'package:nutriq/state/profile_controller.dart';

import 'memory_local_store.dart';

/// Photo service whose next pick result is set by the test.
class FakePhotoService implements PhotoService {
  PhotoPickResult next = const PhotoPicked('/fake/photo.jpg');
  final deleted = <String>[];

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
}

class TestDeps {
  TestDeps._(this.store, this.profile, this.log, this.coach, this.photos, this.analysis);

  final MemoryLocalStore store;
  final ProfileController profile;
  final MealLogController log;
  final CoachController coach;
  final FakePhotoService photos;
  final FoodAnalysisService analysis;

  static Future<TestDeps> create({
    UserProfile? profile,
    AppSettings settings = const AppSettings(onboardingComplete: true),
    List<Meal>? meals,
    FoodAnalysisService? analysis,
  }) async {
    final store = MemoryLocalStore(profile: profile, settings: settings, meals: meals);
    final photos = FakePhotoService();
    final profileCtl = ProfileController(store);
    final log = MealLogController(
      store,
      dayStartHour: () => profileCtl.settings.dayStartHour,
      deletePhoto: photos.delete,
    );
    final coach = CoachController(
      DemoCoachService(replyDelay: Duration.zero),
      CoachController.contextFrom(profileCtl, log),
    );
    await profileCtl.load();
    await log.load();
    return TestDeps._(
      store,
      profileCtl,
      log,
      coach,
      photos,
      analysis ?? DemoFoodAnalysisService(delay: Duration.zero),
    );
  }

  Widget wrap(Widget child) =>
      AppScope(profile: profile, log: log, coach: coach, analysis: analysis, photos: photos, child: child);

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
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<Object?>(builder: (_) => screen)),
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
