import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/scan_draft.dart';
import 'package:nutriq/features/meal_editor/meal_editor_screen.dart';
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
  bool get recognizesPhotos => true;
  @override
  String get label => 'Failing test analysis';
  @override
  Future<FoodAnalysisResult> analyze(Uint8List imageBytes) async {
    calls++;
    throw const FoodAnalysisException('timed out');
  }
}

/// Analysis that finishes only when the test says so (the draft stays "analyzing").
class _GatedAnalysis implements FoodAnalysisService {
  final gate = Completer<FoodAnalysisResult>();
  @override
  bool get isDemo => false;
  @override
  bool get recognizesPhotos => true;
  @override
  String get label => 'Gated test analysis';
  @override
  Future<FoodAnalysisResult> analyze(Uint8List imageBytes) => gate.future;
}

/// The analyzing card animates continuously, so step frames instead of settling.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
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
    for (final label in ['Scan food', 'Photo library', 'Describe meal', 'My foods']) {
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
    expect(deps.photos.deleted, ['/fake/photo.jpg'], reason: 'only the temporary copy goes; the meal keeps its photo');
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

    await tester.tap(find.byTooltip('Discard scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(deps.scans.drafts, isEmpty);
    expect(deps.photos.deleted, ['/fake/photo.jpg', 'meal_photos/test.jpg']);
    expect(deps.log.meals, isEmpty);
  });

  testWidgets('a draft can be discarded while it is analyzing — after confirming — and stays gone', (tester) async {
    final analysis = _GatedAnalysis();
    final deps = await TestDeps.create(analysis: analysis);
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Photo library'));
    await _frames(tester);
    expect(find.text('Analyzing your meal…'), findsOneWidget);
    // Its own accessible button (named by its tooltip), separate from the card's review action.
    final semantics = tester.ensureSemantics();
    final discard = tester.getSemantics(find.byTooltip('Discard scan')).getSemanticsData();
    semantics.dispose();
    expect(discard.tooltip, 'Discard scan');
    expect(discard.hasAction(SemanticsAction.tap), isTrue, reason: 'reachable with VoiceOver / TalkBack');

    await tester.tap(find.byTooltip('Discard scan'));
    await _frames(tester);
    expect(find.text('Discard this scan?'), findsOneWidget);
    expect(find.textContaining('Meals you’ve already logged aren’t affected'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await _frames(tester);
    expect(deps.scans.drafts, hasLength(1), reason: 'cancel keeps it');

    await tester.tap(find.byTooltip('Discard scan'));
    await _frames(tester);
    await tester.tap(find.text('Discard'));
    await _frames(tester);
    expect(deps.scans.drafts, isEmpty);
    expect(deps.photos.deleted, contains('meal_photos/test.jpg'));

    analysis.gate.complete(const FoodAnalysisResult(items: [], isDemo: false));
    await deps.scans.waitForIdle();
    await tester.pumpAndSettle();
    expect(deps.scans.drafts, isEmpty, reason: 'a late result doesn’t bring it back');
    expect(find.text('Analyzing your meal…'), findsNothing);
  });

  testWidgets('discarding a ready draft doesn’t open its review', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Photo library'));
    await tester.pumpAndSettle();
    expect(find.text('Estimate ready'), findsOneWidget);

    await tester.tap(find.byTooltip('Discard scan'));
    await tester.pumpAndSettle();
    expect(find.byType(MealEditorScreen), findsNothing, reason: 'the review didn’t open');
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(deps.scans.drafts, isEmpty);
    expect(find.text('Estimate ready'), findsNothing);
  });

  testWidgets('discarding a draft never deletes a photo a logged meal uses', (tester) async {
    final deps = await TestDeps.create(
      meals: [
        Meal(
          id: 'm',
          loggedAt: DateTime.now(),
          type: MealType.lunch,
          source: MealSource.scan,
          items: const [],
          photoPath: 'meal_photos/test.jpg',
        ),
      ],
    );
    final draft = await deps.scans.startScan('meal_photos/test.jpg');
    await deps.scans.waitForIdle();
    await deps.scans.discard(draft.id);
    expect(deps.scans.drafts, isEmpty);
    expect(deps.photos.deleted, isNot(contains('meal_photos/test.jpg')));
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
    expect(find.text('Demo analysis'), findsOneWidget, reason: 'the camera says results are samples');
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

  testWidgets('Describe meal still lets you enter a food by hand', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Describe meal'));
    await tester.pumpAndSettle();
    expect(find.text('What did you eat?'), findsOneWidget);
    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter manually'));
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
