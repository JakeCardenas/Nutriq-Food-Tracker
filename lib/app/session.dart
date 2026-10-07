import 'dart:async';
import 'dart:typed_data';

import '../data/cloud_repository.dart';
import '../data/local_store.dart';
import '../data/sqlite_local_store.dart';
import '../data/sync_engine.dart';
import '../services/auth/auth_service.dart';
import '../services/coach/coach_backend.dart';
import '../services/coach/coach_service.dart';
import '../services/food_analysis/food_analysis_service.dart';
import '../services/food_analysis/photo_estimate_backend.dart';
import '../services/health/health_service.dart';
import '../services/photo_service.dart';
import '../state/coach_controller.dart';
import '../state/health_controller.dart';
import '../state/meal_log_controller.dart';
import '../state/photo_analysis_controller.dart';
import '../state/profile_controller.dart';
import '../state/scan_controller.dart';
import '../state/sync_controller.dart';

enum SessionMode { local, account }

/// Services shared by every session (they hold no user data).
class SessionServices {
  const SessionServices({
    required this.analysis,
    required this.coach,
    required this.health,
    this.coachBackend,
    this.photoEstimates,
    this.preparePhoto,
  });

  /// On-device photo analysis (or none). Each session wraps it in a [PhotoAnalysisController].
  final FoodAnalysisService analysis;

  /// The optional, opt-in cloud photo estimate. Only signed-in sessions get it.
  final PhotoEstimateBackend? photoEstimates;

  /// Replaces the resize/strip step before upload (tests use fake photos).
  final Future<Uint8List> Function(Uint8List)? preparePhoto;

  /// The scripted coach (always available, and the AI coach's fallback).
  final CoachService coach;
  final HealthService health;

  /// Reaches the AI coach. Only signed-in sessions get it.
  final CoachBackend? coachBackend;
}

/// Everything the UI needs for one mode — local-only, or one signed-in
/// account. Each session has its own database file and photo folder.
class AppSession {
  AppSession._({
    required this.mode,
    required this.user,
    required this.store,
    required this.photos,
    required this.photoAnalysis,
    required this.profile,
    required this.log,
    required this.coach,
    required this.scans,
    required this.health,
    required this.sync,
    required this.cloud,
    required this._cleanups,
  });

  final SessionMode mode;
  final AuthUser? user;
  final LocalStore store;
  final PhotoService photos;

  /// How photos are analysed for this session (on-device, or the opted-in cloud estimate).
  final PhotoAnalysisController photoAnalysis;
  FoodAnalysisService get analysis => photoAnalysis;
  final ProfileController profile;
  final MealLogController log;
  final CoachController coach;
  final ScanController scans;
  final HealthController health;

  /// Present only for a signed-in account.
  final SyncController? sync;

  /// The account's cloud data (only for a signed-in account).
  final CloudRepository? cloud;
  final List<void Function()> _cleanups;

  /// Unique per session instance, so restarting the same account (e.g. after
  /// deleting its data) rebuilds the whole UI instead of reusing old screens.
  late final String key = '${mode == SessionMode.local ? 'local' : 'account:${user!.id}'}#${_generation++}';
  static int _generation = 0;
  bool get isAccount => mode == SessionMode.account;

  Future<void> reload() async {
    await profile.load();
    await log.reload();
  }

  Future<void> dispose() async {
    for (final c in _cleanups) {
      c();
    }
    sync?.dispose();
    scans.dispose();
    health.dispose();
    coach.dispose();
    photoAnalysis.dispose();
    log.dispose();
    profile.dispose();
    await store.close();
  }
}

/// Wires controllers for a session around an already-open [store].
Future<AppSession> assembleSession({
  required AuthUser? user,
  required LocalStore store,
  required PhotoService photos,
  required CloudRepository? cloud,
  required SessionServices services,
  Duration syncDebounce = const Duration(seconds: 2),
}) async {
  final profile = ProfileController(store);
  final log = MealLogController(store, dayStartHour: () => profile.settings.dayStartHour, deletePhoto: photos.delete);
  final coach = CoachController(
    services.coach,
    CoachController.contextFrom(profile, log),
    ai: user == null ? null : services.coachBackend,
    store: store,
  );
  final photoAnalysis = PhotoAnalysisController(
    onDevice: services.analysis,
    cloud: user == null ? null : services.photoEstimates,
    store: store,
    prepare: services.preparePhoto,
  );
  final scans = ScanController(
    store: store,
    analysis: photoAnalysis,
    photos: photos,
    photoInUse: (path) => log.meals.any((m) => m.photoPath == path),
  );
  final health = HealthController(service: services.health, store: store);
  final cleanups = <void Function()>[];

  await profile.load();
  await log.load();
  await scans.load();
  await health.load();
  await coach.load();
  await photoAnalysis.load();

  final healthSub = log.mealChanges.listen(
    (c) => c.after == null ? health.onMealDeleted(c.before!) : health.onMealSaved(c.after!, previous: c.before),
  );
  cleanups.add(healthSub.cancel);

  SyncController? sync;
  if (user != null && cloud != null) {
    final controller = SyncController(
      engine: SyncEngine(store: store, cloud: cloud, onMealPhotoOrphaned: photos.delete),
      store: store,
      debounce: syncDebounce,
      onPulled: () async {
        await profile.load();
        await log.reload();
      },
    );
    sync = controller;
    void onLocalChange() => controller.scheduleSync();
    log.addListener(onLocalChange);
    profile.addListener(onLocalChange);
    cleanups.add(() {
      log.removeListener(onLocalChange);
      profile.removeListener(onLocalChange);
    });
    await controller.refreshCounts();
  }

  return AppSession._(
    mode: user == null ? SessionMode.local : SessionMode.account,
    user: user,
    store: store,
    photos: photos,
    photoAnalysis: photoAnalysis,
    profile: profile,
    log: log,
    coach: coach,
    scans: scans,
    health: health,
    sync: sync,
    cloud: user == null ? null : cloud,
    cleanups: cleanups,
  );
}

/// Opens the on-device files for [user] (or local-only mode) and assembles a session.
Future<AppSession> openDeviceSession({
  required AuthUser? user,
  required CloudRepository? cloud,
  required SessionServices services,
}) async {
  final store = await SqliteLocalStore.open(
    fileName: user == null ? SqliteLocalStore.localFileName : SqliteLocalStore.accountFileName(user.id),
    trackChanges: user != null,
  );
  final photos = await DevicePhotoService.create(userId: user?.id);
  return assembleSession(user: user, store: store, photos: photos, cloud: cloud, services: services);
}
