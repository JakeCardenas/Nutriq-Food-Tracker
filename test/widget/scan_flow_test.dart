import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/scan_draft.dart';
import 'package:nutriq/features/scan/meal_flows.dart';
import 'package:nutriq/services/food_analysis/food_analysis_service.dart';
import 'package:nutriq/services/photo_service.dart';

import '../support/test_app.dart';

/// Analysis that always fails, to exercise the retry / manual / discard paths.
class _FailingAnalysis implements FoodAnalysisService {
  int calls = 0;
  @override
  bool get isDemo => false;
  @override
  String get label => 'Failing test analysis';
  @override
  Future<FoodAnalysisResult> analyze(Uint8List imageBytes) async {
    calls++;
    throw const FoodAnalysisException('timed out');
  }
}

Future<void> _openAddMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('log-meal-button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the + menu offers only ways to log that work', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    for (final label in ['Scan food', 'Photo library', 'Log manually', 'My foods']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('Barcode'), findsNothing);
    expect(find.textContaining('label'), findsNothing);
  });

  testWidgets('photo → draft on Today → review → log; nothing is logged before review', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Photo library'));
    await tester.pumpAndSettle();

    expect(deps.log.meals, isEmpty, reason: 'a scan is a draft until reviewed');
    expect(deps.scans.drafts.single.status, DraftStatus.ready);
    expect(find.text('Estimate ready'), findsOneWidget);
    expect(find.text('Demo'), findsWidgets);

    await tester.tap(find.text('Estimate ready'));
    await tester.pumpAndSettle();
    expect(find.text('Nutrition'), findsOneWidget);
    expect(find.textContaining('Demo result'), findsOneWidget);

    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    expect(deps.log.meals.single.source, MealSource.demoScan);
    expect(deps.log.meals.single.photoPath, 'meal_photos/test.jpg');
    expect(deps.scans.drafts, isEmpty);
    expect(deps.photos.deleted, isEmpty, reason: 'the logged meal keeps its photo');
    expect(find.text('Estimate ready'), findsNothing);
  });

  testWidgets('closing a review keeps the draft for later', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Photo library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estimate ready'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(deps.scans.drafts, hasLength(1));
    expect(deps.log.meals, isEmpty);
  });

  testWidgets('a failed analysis can be retried, logged manually, or discarded', (tester) async {
    final analysis = _FailingAnalysis();
    final deps = await TestDeps.create(analysis: analysis);
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Photo library'));
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t analyze'), findsOneWidget);
    expect(find.textContaining('timed out'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(analysis.calls, 2);
    expect(find.text('Couldn’t analyze'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(deps.scans.drafts, isEmpty);
    expect(deps.photos.deleted, ['meal_photos/test.jpg']);
    expect(deps.log.meals, isEmpty);
  });

  testWidgets('a denied photo library explains what to do', (tester) async {
    final deps = await TestDeps.create();
    deps.photos.next = const PhotoPickFailed(PhotoFailure.permissionDenied, PhotoSource.library);
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Photo library'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Photo access is off'), findsOneWidget);
    expect(deps.scans.drafts, isEmpty);
  });

  testWidgets('without a usable camera, the camera screen falls back to the library', (tester) async {
    MealFlows.loadCameras = () async => const []; // like the iOS Simulator
    addTearDown(() => MealFlows.loadCameras = availableCameras);
    final deps = await TestDeps.create();
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Scan food'));
    await tester.pumpAndSettle();

    expect(find.text('Camera isn’t available'), findsOneWidget);
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();
    expect(deps.scans.drafts, hasLength(1));
    expect(find.text('Estimate ready'), findsOneWidget, reason: 'back on Today');
  });

  testWidgets('a denied camera says how to allow it and still offers the library', (tester) async {
    MealFlows.loadCameras = () async => throw CameraException('CameraAccessDenied', 'denied');
    addTearDown(() => MealFlows.loadCameras = availableCameras);
    final deps = await TestDeps.create();
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Scan food'));
    await tester.pumpAndSettle();
    expect(find.text('Camera access is off'), findsOneWidget);
    expect(find.text('Choose from library'), findsOneWidget);
    expect(deps.scans.drafts, isEmpty);
  });

  testWidgets('Log manually opens the ingredient form', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Log manually'));
    await tester.pumpAndSettle();
    expect(find.text('Add an ingredient'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Food name'), 'Oatmeal');
    await tester.enterText(find.widgetWithText(TextFormField, 'Calories per serving'), '300');
    await tester.tap(find.text('Add to meal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    expect(deps.log.meals.single.items.single.name, 'Oatmeal');
    expect(deps.log.meals.single.source, MealSource.manual);
  });
}
