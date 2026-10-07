import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/env.dart';
import 'app/nutriq_app.dart';
import 'app/session.dart';
import 'data/cloud_repository.dart';
import 'data/sqlite_local_store.dart';
import 'data/supabase_coach_backend.dart';
import 'services/food_analysis/photo_estimate_backend.dart';
import 'data/supabase_cloud_repository.dart';
import 'services/auth/auth_service.dart';
import 'services/auth/supabase_auth_service.dart';
import 'services/coach/demo_coach_service.dart';
import 'services/food_analysis/no_photo_recognition_service.dart';
import 'services/food_analysis/on_device_food_analysis_service.dart';
import 'services/health/health_service.dart';
import 'services/health/healthkit_service.dart';
import 'services/photo_service.dart';
import 'state/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

  // Cloud accounts are optional: without config/nutriq.json the app runs
  // fully on the device. Only the public URL + publishable key are used here.
  AuthService auth = const DisabledAuthService();
  CloudRepository? cloud;
  SupabaseCoachBackend? coachBackend;
  PhotoEstimateBackend? photoEstimates;
  if (Env.cloudConfigured) {
    try {
      await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
      final client = Supabase.instance.client;
      auth = SupabaseAuthService(client);
      cloud = SupabaseCloudRepository(client);
      if (Env.aiCoachEnabled) coachBackend = SupabaseCoachBackend(client);
      if (Env.photoEstimatesEnabled) photoEstimates = SupabasePhotoEstimateBackend(client);
    } catch (e) {
      debugPrint('Supabase not available, staying local-only: $e');
    }
  }

  // Photos are recognised on the iPhone (Apple Vision) and matched to the
  // built-in food list; elsewhere the person describes the meal instead.
  // The coach is scripted on the device;
  // signed-in people can opt in to the AI coach, which runs through the
  // `coach` server function (the AI key never ships in the app).
  final services = SessionServices(
    analysis: Platform.isIOS ? OnDeviceFoodAnalysisService() : const NoPhotoRecognitionService(),
    coach: DemoCoachService(),
    coachBackend: coachBackend,
    photoEstimates: photoEstimates,
    health: Platform.isIOS ? HealthKitService() : const UnsupportedHealthService(),
  );

  final sessions = SessionController(
    auth: auth,
    buildSession: (user) => openDeviceSession(user: user, cloud: user == null ? null : cloud, services: services),
    openLocalStore: () => SqliteLocalStore.open(),
    localPhotos: await DevicePhotoService.create(),
  );
  sessions.start();

  runApp(NutriqApp(sessions: sessions, auth: auth));
}
