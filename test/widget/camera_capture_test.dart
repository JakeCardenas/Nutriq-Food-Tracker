import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/features/scan/camera_screen.dart';

import '../support/test_app.dart';

const _capture = '/tmp/camera/capture.jpg';

/// The camera right after the shutter (widget tests have no real camera).
Future<TestDeps> _justTookPhoto(WidgetTester tester) async {
  final deps = await TestDeps.create();
  await deps.pumpPushed(
    tester,
    CameraScreen(loadCameras: () async => const <CameraDescription>[], initialCapture: _capture),
  );
  return deps;
}

void main() {
  testWidgets('a new photo waits for Use photo, Retake or Discard — nothing is saved yet', (tester) async {
    final deps = await _justTookPhoto(tester);

    expect(find.text('Use this photo?'), findsOneWidget);
    expect(find.text('Use photo'), findsOneWidget);
    expect(find.text('Retake'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Camera isn’t available'), findsNothing, reason: 'the review covers the whole screen');
    expect(deps.scans.drafts, isEmpty);
    expect(deps.photos.deleted, isEmpty);
  });

  testWidgets('Retake deletes the capture and goes back to the camera', (tester) async {
    final deps = await _justTookPhoto(tester);

    await tester.tap(find.text('Retake'));
    await tester.pumpAndSettle();

    expect(deps.photos.deleted, [_capture]);
    expect(find.text('Use photo'), findsNothing);
    expect(find.byTooltip('Close camera'), findsOneWidget, reason: 'still on the camera');
    expect(deps.scans.drafts, isEmpty);
  });

  testWidgets('Discard deletes the capture and closes without a draft or an upload', (tester) async {
    final deps = await _justTookPhoto(tester);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(deps.photos.deleted, [_capture]);
    expect(find.text('open'), findsOneWidget, reason: 'back where the camera was opened from');
    expect(deps.scans.drafts, isEmpty);
  });

  testWidgets('closing the camera while reviewing also discards the capture', (tester) async {
    final deps = await _justTookPhoto(tester);

    await tester.tap(find.byTooltip('Close camera'));
    await tester.pumpAndSettle();

    expect(deps.photos.deleted, [_capture]);
    expect(deps.scans.drafts, isEmpty);
  });

  testWidgets('if the temporary capture can’t be removed, the photo is still used', (tester) async {
    final deps = await _justTookPhoto(tester);
    deps.photos.failDeleting.add(_capture);

    await tester.tap(find.text('Use photo'));
    await tester.pumpAndSettle();
    await deps.scans.waitForIdle();

    expect(deps.scans.drafts, hasLength(1), reason: 'the stored copy isn’t orphaned');
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('only Use photo saves a draft; the temporary capture is removed once stored', (tester) async {
    final deps = await _justTookPhoto(tester);

    await tester.tap(find.text('Use photo'));
    await tester.pumpAndSettle();
    await deps.scans.waitForIdle();

    expect(deps.scans.drafts, hasLength(1));
    expect(deps.scans.drafts.single.photoPath, 'meal_photos/test.jpg');
    expect(deps.photos.deleted, [_capture], reason: 'the stored copy is kept, the temporary one is not');
    expect(find.text('open'), findsOneWidget);
  });
}
