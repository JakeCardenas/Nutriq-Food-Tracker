import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../domain/models/meal.dart';
import '../../domain/models/scan_draft.dart';
import '../../services/photo_service.dart';
import '../../widgets/adaptive.dart';
import '../meal_editor/meal_editor_screen.dart';
import 'camera_screen.dart';

/// Navigation for logging: camera → draft (analyzed in the background) →
/// review → log. Nothing is logged until the person saves the review.
abstract final class MealFlows {
  /// Where the camera screen gets its cameras (replaced in widget tests).
  @visibleForTesting
  static Future<List<CameraDescription>> Function() loadCameras = availableCameras;

  /// Opens the in-app camera. A captured photo becomes a draft on Today.
  static Future<void> openCamera(BuildContext context) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      pageBuilder: (_, _, _) => CameraScreen(loadCameras: loadCameras),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  );

  /// Picks a photo from the library and starts a draft. Returns true if one started.
  static Future<bool> pickFromLibrary(BuildContext context) async {
    final scope = AppScope.of(context);
    final result = await scope.photos.pick(PhotoSource.library);
    if (!context.mounted) return false;
    switch (result) {
      case PhotoCancelled():
        return false;
      case PhotoPickFailed():
        showToast(context, photoFailureMessage(result));
        return false;
      case PhotoPicked(:final tempPath):
        await startDraft(context, tempPath);
        return true;
    }
  }

  /// Stores a captured/picked photo on this phone and starts analyzing it.
  static Future<void> startDraft(BuildContext context, String tempPath) async {
    final scope = AppScope.of(context);
    final stored = await scope.photos.persist(tempPath);
    await scope.scans.startScan(stored);
  }

  static String photoFailureMessage(PhotoPickFailed f) => switch (f.failure) {
    PhotoFailure.permissionDenied when f.source == PhotoSource.camera =>
      'Camera access is off. Allow it in Settings → Nutriq, or choose a photo instead.',
    PhotoFailure.permissionDenied => 'Photo access is off. Allow it in Settings → Nutriq → Photos.',
    PhotoFailure.cameraUnavailable => 'No camera is available on this device.',
    PhotoFailure.unknown => 'Couldn’t open photos. Try again, or log the meal manually.',
  };

  /// Opens the review for a ready draft.
  static Future<void> reviewDraft(BuildContext context, ScanDraft draft) => _push(
    context,
    MealEditorScreen(
      initialItems: draft.items,
      photoPath: draft.photoPath,
      source: draft.isDemo ? MealSource.demoScan : MealSource.scan,
      demoSampleName: draft.sampleName,
      emptyResult: draft.items.isEmpty,
      draftId: draft.id,
    ),
  );

  /// Logs a draft's photo with foods entered by hand (e.g. after a failed analysis).
  static Future<void> manualFromDraft(BuildContext context, ScanDraft draft) => _push(
    context,
    MealEditorScreen(photoPath: draft.photoPath, openAddFood: true, startManualEntry: true, draftId: draft.id),
  );

  /// A new meal, starting with the manual food form.
  static Future<void> openManual(BuildContext context, {DateTime? at}) =>
      _push(context, MealEditorScreen(openAddFood: true, startManualEntry: true, initialLoggedAt: at));

  /// A new meal, starting from My foods and recent foods.
  static Future<void> openMyFoods(BuildContext context) => _push(context, const MealEditorScreen(openAddFood: true));

  static Future<void> openMeal(BuildContext context, Meal meal) => _push(context, MealEditorScreen.edit(meal));

  static Future<void> _push(BuildContext context, MealEditorScreen editor) async {
    final result = await Navigator.of(context)
        .push<EditorResult>(MaterialPageRoute(fullscreenDialog: editor.existing == null, builder: (_) => editor));
    if (result != null && context.mounted) showToast(context, result.message);
  }
}
