import 'package:flutter/widgets.dart';

import '../services/auth/auth_service.dart';
import '../services/food_analysis/food_analysis_service.dart';
import '../services/photo_service.dart';
import '../state/coach_controller.dart';
import '../state/health_controller.dart';
import '../state/meal_log_controller.dart';
import '../state/profile_controller.dart';
import '../state/scan_controller.dart';
import '../state/session_controller.dart';
import '../state/sync_controller.dart';
import 'session.dart';

/// Hands the active session's controllers and services to the widget tree.
/// The subtree is rebuilt (keyed by session) whenever the account changes, so
/// widgets never hold controllers from another account.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.sessions, required this.session, required this.auth, required super.child});

  final SessionController sessions;
  final AppSession session;
  final AuthService auth;

  ProfileController get profile => session.profile;
  MealLogController get log => session.log;
  CoachController get coach => session.coach;
  ScanController get scans => session.scans;
  HealthController get health => session.health;
  SyncController? get sync => session.sync;
  PhotoService get photos => session.photos;
  FoodAnalysisService get analysis => session.analysis;

  static AppScope of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above $context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.session != session;
}
