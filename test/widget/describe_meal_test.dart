import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/food_catalog.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/services/food_analysis/food_analysis_service.dart';
import 'package:nutriq/services/food_analysis/no_photo_recognition_service.dart';

import '../support/test_app.dart';

/// Real (non-demo) photo recognition that found rice.
class _FoundRice implements FoodAnalysisService {
  @override
  bool get isDemo => false;
  @override
  bool get recognizesPhotos => true;
  @override
  String get label => 'Test recognizer';
  @override
  Future<FoodAnalysisResult> analyze(Uint8List imageBytes) async =>
      FoodAnalysisResult(items: [FoodCatalog.byAlias('rice')!.item().copyWith(confidence: 0.8)], isDemo: false);
}

/// Real photo recognition that saw no food.
class _FoundNothing implements FoodAnalysisService {
  @override
  bool get isDemo => false;
  @override
  bool get recognizesPhotos => true;
  @override
  String get label => 'Test recognizer';
  @override
  Future<FoodAnalysisResult> analyze(Uint8List imageBytes) async => const FoodAnalysisResult(items: [], isDemo: false);
}

Future<void> _openAddMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('log-meal-button')));
  await tester.pumpAndSettle();
}

Future<void> _describe(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.byKey(const ValueKey('describe-field')));
  await tester.enterText(find.byKey(const ValueKey('describe-field')), text);
  await tester.pump();
  await tester.ensureVisible(find.text('Add foods'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add foods'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('+ → Describe meal → foods with real numbers → log', (tester) async {
    final deps = await TestDeps.create(analysis: const NoPhotoRecognitionService());
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Describe meal'));
    await tester.pumpAndSettle();

    expect(find.text('What did you eat?'), findsOneWidget);
    await _describe(tester, 'century tuna and 2 cups of rice');
    expect(find.text('Century Tuna flakes in oil'), findsOneWidget);
    expect(find.text('White rice, cooked'), findsOneWidget);
    expect(find.text('What did you eat?'), findsNothing, reason: 'the card steps aside once there are foods');

    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    final meal = deps.log.meals.single;
    expect(meal.items.map((i) => i.name), ['Century Tuna flakes in oil', 'White rice, cooked']);
    expect(meal.source, MealSource.manual);
    expect(meal.totals.calories, inInclusiveRange(600, 700));
  });

  testWidgets('foods Nutriq doesn’t know are listed, not guessed', (tester) async {
    final deps = await TestDeps.create(analysis: const NoPhotoRecognitionService());
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Describe meal'));
    await tester.pumpAndSettle();

    await _describe(tester, 'zorblax');
    expect(find.textContaining('Not in Nutriq’s food list: “zorblax”'), findsOneWidget);
    expect(deps.log.meals, isEmpty);
  });

  testWidgets('a photo opens “What’s in this photo?” — no made-up meal, no draft', (tester) async {
    final deps = await TestDeps.create(analysis: const NoPhotoRecognitionService());
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Photo library'));
    await tester.pumpAndSettle();

    expect(find.text('What’s in this photo?'), findsOneWidget);
    expect(deps.scans.drafts, isEmpty);
    expect(find.textContaining('Demo'), findsNothing);

    await _describe(tester, '2 eggs and garlic rice');
    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    final meal = deps.log.meals.single;
    expect(meal.photoPath, 'meal_photos/test.jpg');
    expect(meal.items, hasLength(2));
  });

  testWidgets('closing the describe step after a photo deletes that photo', (tester) async {
    final deps = await TestDeps.create(analysis: const NoPhotoRecognitionService());
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Photo library'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(deps.log.meals, isEmpty);
    expect(deps.photos.deleted, ['meal_photos/test.jpg']);
  });

  testWidgets('“Add an ingredient” search includes Nutriq’s food list', (tester) async {
    final deps = await TestDeps.create(analysis: const NoPhotoRecognitionService());
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Describe meal'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Search foods'), 'longgan');
    await tester.pumpAndSettle();
    expect(find.text('Food list'), findsOneWidget);
    await tester.tap(find.text('Longganisa'));
    await tester.pumpAndSettle();
    expect(find.text('Longganisa'), findsWidgets, reason: 'the ingredient (and the meal title)');
    expect(find.text('What did you eat?'), findsNothing);
  });

  testWidgets('a recognised photo: check the amounts, and describe what it missed', (tester) async {
    final deps = await TestDeps.create(analysis: _FoundRice());
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Photo library'));
    await tester.pumpAndSettle();
    expect(find.text('Foods found'), findsOneWidget);
    expect(find.textContaining('White rice'), findsOneWidget, reason: 'the Today card names what it saw');
    await tester.tap(find.text('Foods found'));
    await tester.pumpAndSettle();

    expect(find.text('White rice, cooked'), findsWidgets);
    expect(find.text('Check what was found'), findsOneWidget);
    expect(find.textContaining('not brands or amounts'), findsOneWidget);
    expect(find.text('Anything missing? Describe it'), findsOneWidget);

    await _describe(tester, 'century tuna');
    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    final meal = deps.log.meals.single;
    expect(meal.items.map((i) => i.name), ['White rice, cooked', 'Century Tuna flakes in oil']);
    expect(meal.source, MealSource.scan);
  });

  testWidgets('a photo with no food: the card says so and asks what it was', (tester) async {
    final deps = await TestDeps.create(analysis: _FoundNothing());
    await deps.pumpApp(tester);
    await _openAddMenu(tester);
    await tester.tap(find.text('Photo library'));
    await tester.pumpAndSettle();
    expect(find.text('No food found'), findsOneWidget);
    expect(find.text('Estimate ready'), findsNothing);

    await tester.tap(find.text('No food found'));
    await tester.pumpAndSettle();
    expect(find.text('What’s in this photo?'), findsOneWidget);
    await _describe(tester, 'tocilog');
    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    expect(deps.log.meals.single.items.single.name, 'Tocilog');
  });
}
