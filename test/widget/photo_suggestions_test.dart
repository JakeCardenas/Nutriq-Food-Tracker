import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/photo_suggestion.dart';
import 'package:nutriq/features/meal_editor/photo_suggestions_card.dart';
import 'package:nutriq/services/food_analysis/food_analysis_service.dart';
import 'package:nutriq/services/food_analysis/no_photo_recognition_service.dart';

import '../support/test_app.dart';

/// On-device recognition that suggests a fried egg (one food) and tuna (could be several).
class _Suggests implements FoodAnalysisService {
  @override
  bool get isDemo => false;
  @override
  bool get recognizesPhotos => true;
  @override
  String get label => 'Test suggestions';
  @override
  Future<FoodAnalysisResult> analyze(Uint8List imageBytes) async => const FoodAnalysisResult(
    items: [],
    isDemo: false,
    suggestions: [
      PhotoSuggestion(label: 'Fried egg', searchTerm: 'egg', foodName: 'Egg, fried'),
      PhotoSuggestion(label: 'Tuna', searchTerm: 'tuna'),
    ],
  );
}

Future<TestDeps> _reviewPhoto(WidgetTester tester) async {
  final deps = await TestDeps.create(analysis: _Suggests());
  await deps.pumpApp(tester);
  await tester.tap(find.byKey(const ValueKey('log-meal-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Photo library'));
  await tester.pumpAndSettle();
  return deps;
}

Future<void> _openReview(WidgetTester tester) async {
  await tester.tap(find.text('Ready to review'));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _rowButton(String label, String button) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(PhotoSuggestionRow)),
  matching: find.text(button),
);

void main() {
  testWidgets('Today says what the photo might include, without claiming it found food', (tester) async {
    await _reviewPhoto(tester);
    expect(find.text('Ready to review'), findsOneWidget);
    expect(find.textContaining('Might include: Fried egg · Tuna'), findsOneWidget);
    expect(find.text('Foods found'), findsNothing);
  });

  testWidgets('suggestions are offered, not added — nothing to log until you choose', (tester) async {
    final deps = await _reviewPhoto(tester);
    await _openReview(tester);

    expect(find.text('Might be in your photo'), findsOneWidget);
    expect(find.textContaining('can be wrong'), findsOneWidget);
    expect(_rowButton('Fried egg', 'Add'), findsOneWidget);
    expect(_rowButton('Tuna', 'Find'), findsOneWidget);
    expect(find.text('Egg, fried'), findsNothing, reason: 'not an ingredient until chosen');

    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    expect(deps.log.meals, isEmpty);
  });

  testWidgets('Add asks for the serving first, and says it is a suggestion', (tester) async {
    final deps = await _reviewPhoto(tester);
    await _openReview(tester);

    await _tapVisible(tester, _rowButton('Fried egg', 'Add'));
    expect(find.byKey(const ValueKey('serving-sheet')), findsOneWidget);
    expect(find.text('Egg, fried'), findsOneWidget);
    expect(find.textContaining('Suggested serving'), findsOneWidget);
    expect(find.textContaining('estimate'), findsWidgets);

    final plus = find.descendant(
      of: find.byKey(const ValueKey('serving-sheet')),
      matching: find.byIcon(Icons.add_rounded),
    );
    for (var i = 0; i < 4; i++) {
      await tester.tap(plus); // 1 → 2 in steps of ¼
      await tester.pump();
    }
    await tester.tap(find.text('Add to meal'));
    await tester.pumpAndSettle();

    expect(find.text('Egg, fried'), findsWidgets);
    expect(_rowButton('Fried egg', 'Add'), findsNothing, reason: 'the suggestion was used');
    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    final meal = deps.log.meals.single;
    expect(meal.items.single.name, 'Egg, fried');
    expect(meal.items.single.servings, 2);
    expect(meal.source, MealSource.scan);
  });

  testWidgets('closing the serving sheet adds nothing', (tester) async {
    await _reviewPhoto(tester);
    await _openReview(tester);
    await _tapVisible(tester, _rowButton('Fried egg', 'Add'));
    Navigator.of(tester.element(find.byKey(const ValueKey('serving-sheet')))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Egg, fried'), findsNothing);
    expect(_rowButton('Fried egg', 'Add'), findsOneWidget);
  });

  testWidgets('Find searches the food list so you pick the right one', (tester) async {
    final deps = await _reviewPhoto(tester);
    await _openReview(tester);

    await _tapVisible(tester, _rowButton('Tuna', 'Find'));
    expect(find.text('Tuna flakes in oil, canned'), findsOneWidget);
    expect(find.text('Tuna in water, canned'), findsOneWidget);
    await tester.tap(find.text('Tuna in water, canned'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('serving-sheet')), findsOneWidget);
    await tester.tap(find.text('Add to meal'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    expect(deps.log.meals.single.items.single.name, 'Tuna in water, canned');
  });

  testWidgets('a wrong suggestion can be removed', (tester) async {
    await _reviewPhoto(tester);
    await _openReview(tester);
    await _tapVisible(
      tester,
      find.descendant(
        of: find.ancestor(of: find.text('Tuna'), matching: find.byType(PhotoSuggestionRow)),
        matching: find.byTooltip('Not in my meal'),
      ),
    );
    expect(find.text('Tuna'), findsNothing);
    expect(find.text('Fried egg'), findsOneWidget);
  });

  testWidgets('the serving sheet lets you pick another portion size', (tester) async {
    final deps = await TestDeps.create(analysis: const NoPhotoRecognitionService());
    await deps.pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('log-meal-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Describe meal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Search foods'), 'kanin');
    await tester.pumpAndSettle();
    await tester.tap(find.text('White rice, cooked'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1 bowl (240 g)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('312 kcal'), findsOneWidget);
    await tester.tap(find.text('Add to meal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    expect(deps.log.meals.single.items.single.servingLabel, '1 bowl (240 g)');
  });

  testWidgets('without photo recognition the menu says “Take photo”, not “Scan food”', (tester) async {
    final deps = await TestDeps.create(analysis: const NoPhotoRecognitionService());
    await deps.pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('log-meal-button')));
    await tester.pumpAndSettle();
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Scan food'), findsNothing);
  });
}
