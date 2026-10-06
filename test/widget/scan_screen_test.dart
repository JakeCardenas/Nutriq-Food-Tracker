import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/features/scan/scan_screen.dart';
import 'package:nutriq/services/food_analysis/food_analysis_service.dart';
import 'package:nutriq/services/photo_service.dart';

import '../support/test_app.dart';

class _ThrowingAnalysis implements FoodAnalysisService {
  @override
  bool get isDemo => false;
  @override
  String get label => 'broken';
  @override
  Future<FoodAnalysisResult> analyze(Uint8List imageBytes) async =>
      throw const FoodAnalysisException('server unavailable');
}

class _EmptyAnalysis implements FoodAnalysisService {
  @override
  bool get isDemo => false;
  @override
  String get label => 'empty';
  @override
  Future<FoodAnalysisResult> analyze(Uint8List imageBytes) async =>
      const FoodAnalysisResult(items: [], isDemo: false);
}

void main() {
  testWidgets('demo mode is announced before choosing a photo', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpPushed(tester, const ScanScreen());
    expect(find.textContaining('Demo analysis'), findsOneWidget);
  });

  testWidgets('cancelling the picker stays put without an error', (tester) async {
    final deps = await TestDeps.create();
    deps.photos.next = const PhotoCancelled();
    await deps.pumpPushed(tester, const ScanScreen());
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();
    expect(find.text('Choose photo'), findsOneWidget);
    expect(find.textContaining('access is off'), findsNothing);
  });

  testWidgets('permission denied explains how to fix it and offers manual entry', (tester) async {
    final deps = await TestDeps.create();
    deps.photos.next = const PhotoPickFailed(PhotoFailure.permissionDenied, PhotoSource.camera);
    await deps.pumpPushed(tester, const ScanScreen());
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Camera access is off'), findsOneWidget);
    expect(find.text('Enter manually'), findsOneWidget);
  });

  testWidgets('a successful demo scan opens the review screen', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpPushed(tester, const ScanScreen());
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();
    expect(find.text('Review estimate'), findsOneWidget);
    expect(find.textContaining('Demo result'), findsOneWidget);
  });

  testWidgets('analysis errors offer retry and manual entry', (tester) async {
    final deps = await TestDeps.create(analysis: _ThrowingAnalysis());
    await deps.pumpPushed(tester, const ScanScreen());
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Couldn’t estimate this photo'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Enter manually'));
    await tester.pumpAndSettle();
    expect(find.text('Add meal'), findsOneWidget);
  });

  testWidgets('an empty result opens the editor ready for manual foods', (tester) async {
    final deps = await TestDeps.create(analysis: _EmptyAnalysis());
    await deps.pumpPushed(tester, const ScanScreen());
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();
    expect(find.text('No foods suggested'), findsOneWidget);
  });

  testWidgets('abandoning the review deletes the stored photo', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpPushed(tester, const ScanScreen());
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(deps.photos.deleted, ['meal_photos/test.jpg']);
    expect(deps.log.meals, isEmpty);
  });
}
