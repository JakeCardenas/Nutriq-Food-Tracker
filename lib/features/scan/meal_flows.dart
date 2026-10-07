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

  /// Opens the in-app camera. A captured photo becomes a draft on Today, or —
  /// when photos aren't analysed — goes straight to "What's in this photo?".
  static Future<void> openCamera(BuildContext context) async {
    final toDescribe = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        fullscreenDialog: true,
        pageBuilder: (_, _, _) => CameraScreen(loadCameras: loadCameras),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
    if (toDescribe != null && context.mounted) await describePhoto(context, toDescribe);
  }

  /// From the + menu: pick a library photo, then review or describe it.
  static Future<void> pickFromLibrary(BuildContext context) async {
    final chosen = await choosePhoto(context);
    if (chosen.toDescribe != null && context.mounted) await describePhoto(context, chosen.toDescribe!);
  }

  /// Picks a library photo and stores it. [picked] is false when nothing was
  /// chosen; [toDescribe] is the stored photo when it still needs describing.
  static Future<({bool picked, String? toDescribe})> choosePhoto(BuildContext context) async {
    final scope = AppScope.of(context);
    final result = await scope.photos.pick(PhotoSource.library);
    if (!context.mounted) return (picked: false, toDescribe: null);
    switch (result) {
      case PhotoCancelled():
        return (picked: false, toDescribe: null);
      case PhotoPickFailed():
        showToast(context, photoFailureMessage(result));
        return (picked: false, toDescribe: null);
      case PhotoPicked(:final tempPath):
        return (picked: true, toDescribe: await startDraft(context, tempPath));
    }
  }

  /// Stores a captured/picked photo on this phone and starts analyzing it.
  /// Returns the stored path instead when photos aren't analysed, so the
  /// caller can ask what's in it.
  static Future<String?> startDraft(BuildContext context, String tempPath) async {
    final scope = AppScope.of(context);
    final stored = await scope.photos.persist(tempPath);
    if (!scope.analysis.recognizesPhotos) return stored;
    await scope.scans.startScan(stored);
    return null;
  }

  /// "What's in this photo?" — the photo is kept only if a meal is logged.
  static Future<void> describePhoto(BuildContext context, String storedPhotoPath) async {
    final photos = AppScope.of(context).photos;
    final result = await Navigator.of(context).push<EditorResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MealEditorScreen(photoPath: storedPhotoPath, describeFirst: true),
      ),
    );
    if (result?.mealSaved != true) await photos.delete(storedPhotoPath);
    if (result != null && context.mounted) showToast(context, result.message);
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

  /// Logs a draft's photo with foods the person describes (e.g. after a failed analysis).
  static Future<void> manualFromDraft(BuildContext context, ScanDraft draft) =>
      _push(context, MealEditorScreen(photoPath: draft.photoPath, describeFirst: true, draftId: draft.id));

  /// A new meal, starting with "What did you eat?".
  static Future<void> openManual(BuildContext context, {DateTime? at}) =>
      _push(context, MealEditorScreen(describeFirst: true, initialLoggedAt: at));

  /// A new meal, starting from My foods and recent foods.
  static Future<void> openMyFoods(BuildContext context) => _push(context, const MealEditorScreen(openAddFood: true));

  static Future<void> openMeal(BuildContext context, Meal meal) => _push(context, MealEditorScreen.edit(meal));

  static Future<void> _push(BuildContext context, MealEditorScreen editor) async {
    final result = await Navigator.of(context)
        .push<EditorResult>(MaterialPageRoute(fullscreenDialog: editor.existing == null, builder: (_) => editor));
    if (result != null && context.mounted) showToast(context, result.message);
  }
}
