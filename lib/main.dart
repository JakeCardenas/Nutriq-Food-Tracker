import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/env.dart';
import 'app/nutriq_app.dart';
import 'app/session.dart';
import 'data/cloud_repository.dart';
import 'data/sqlite_local_store.dart';
import 'data/supabase_cloud_repository.dart';
import 'services/auth/auth_service.dart';
import 'services/auth/supabase_auth_service.dart';
import 'services/coach/demo_coach_service.dart';
import 'services/food_analysis/demo_food_analysis_service.dart';
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
  if (Env.cloudConfigured) {
    try {
      await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
      final client = Supabase.instance.client;
      auth = SupabaseAuthService(client);
      cloud = SupabaseCloudRepository(client);
    } catch (e) {
      debugPrint('Supabase not available, staying local-only: $e');
    }
  }

  // Demo implementations — clearly labelled in the UI. To connect real
  // services, implement FoodAnalysisService / CoachService against your own
  // backend (which keeps provider keys server-side) and swap them in here.
  final services = SessionServices(
    analysis: DemoFoodAnalysisService(),
    coach: DemoCoachService(),
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
