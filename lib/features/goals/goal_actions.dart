import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/starting_point.dart';
import '../../state/profile_controller.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/sheet.dart';
import 'goal_editors.dart';

/// Opens the calorie-range editor for the current profile and saves the
/// result through [ProfileController.setCalorieGoal] (which re-checks bounds).
Future<void> editCalorieGoal(BuildContext context) async {
  final controller = AppScope.of(context).profile;
  final profile = controller.profile ?? const UserProfile();
  if (profile.isMinor) {
    await showNqSheet<void>(context, title: 'Calorie goal', child: const NoTargetsForMinorsNotice());
    return;
  }
  final floor = CalorieBounds.floorFor(profile);
  final suggested = StartingPoint.calculate(profile).range;
  final initial = profile.calorieGoal ?? suggested ?? CalorieRange(min: floor, max: floor + 300);
  final edit = await showCalorieRangeEditor(
    context,
    profile: profile,
    initial: initial,
    allowRemove: profile.calorieGoal != null,
    note: profile.hasHealthConsideration
        ? 'Enter the range your doctor or dietitian suggested. Nutriq won’t calculate one for you.'
        : null,
  );
  if (edit == null) return;
  try {
    await controller.setCalorieGoal(edit.range);
    if (context.mounted) showToast(context, edit.range == null ? 'Calorie goal removed' : 'Calorie goal saved');
  } on CalorieGoalRejected catch (e) {
    if (context.mounted) showToast(context, e.message);
  }
}

/// Opens the protein-reference editor and saves the result.
Future<void> editProteinTarget(BuildContext context) async {
  final controller = AppScope.of(context).profile;
  final profile = controller.profile ?? const UserProfile();
  if (profile.isMinor) {
    await showNqSheet<void>(context, title: 'Protein reference', child: const NoTargetsForMinorsNotice());
    return;
  }
  final suggested = StartingPoint.calculate(profile).proteinReferenceG;
  final grams = await showProteinEditor(
    context,
    initial: profile.proteinTargetG ?? suggested ?? 100,
    allowRemove: profile.proteinTargetG != null,
  );
  if (grams == null) return;
  await controller.setProteinTarget(grams == 0 ? null : grams);
}
