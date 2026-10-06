import 'package:flutter/widgets.dart';

import '../services/food_analysis/food_analysis_service.dart';
import '../services/photo_service.dart';
import '../state/coach_controller.dart';
import '../state/meal_log_controller.dart';
import '../state/profile_controller.dart';

/// Hands controllers and services to the widget tree. The instances never
/// change; widgets listen to the controllers themselves.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.profile,
    required this.log,
    required this.coach,
    required this.analysis,
    required this.photos,
    required super.child,
  });

  final ProfileController profile;
  final MealLogController log;
  final CoachController coach;
  final FoodAnalysisService analysis;
  final PhotoService photos;

  static AppScope of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above $context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
