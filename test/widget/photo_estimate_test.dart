import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/features/meal_editor/photo_estimate_card.dart';
import 'package:nutriq/features/scan/camera_screen.dart';
import 'package:nutriq/services/auth/auth_service.dart';
import 'package:nutriq/services/food_analysis/no_photo_recognition_service.dart';
import 'package:nutriq/services/food_analysis/photo_estimate_backend.dart';
import 'package:nutriq/widgets/surfaces.dart';

import '../support/fake_auth.dart';
import '../support/fake_cloud.dart';
import '../support/test_app.dart';

const _alice = AuthUser(id: 'alice', email: 'alice@example.com', providers: ['email']);

/// Stands in for the scan-photo function (no network, no real photo).
class _FakeEstimates implements PhotoEstimateBackend {
  final sent = <Uint8List>[];
  PhotoEstimateException? error;
  Map<String, Object?>? response;

  @override
  Future<Map<String, Object?>> estimate(Uint8List jpeg) async {
    sent.add(jpeg);
    if (error != null) throw error!;
    return response ??
        {
          'isFood': true,
          'dish': 'Tuna and rice',
          'dishAlternatives': ['Tuna rice bowl'],
          'foods': [
            {
              'name': 'white rice, cooked',
              'localName': 'kanin',
              'visibility': 'visible',
              'grams': {'low': 250, 'high': 330, 'note': 'about 2 cups'},
              'fdc': null,
            },
            {
              'name': 'tuna, canned in oil, drained',
              'localName': null,
              'visibility': 'visible',
              'grams': null,
              'fdc': {
                'fdcId': 175159,
                'description': 'Fish, tuna, light, canned in oil, drained solids',
                'dataType': 'SR Legacy',
                'kcal': 198,
                'protein': 29.1,
                'carbs': 0,
                'fat': 8.2,
              },
            },
            {'name': 'brown sauce', 'localName': null, 'visibility': 'inferred', 'grams': null, 'fdc': null},
          ],
          'uncertainties': ['Oil from the can may be on the rice'],
          'remaining': 9,
          'nutritionLookup': 'fdc',
        };
  }
}

late _FakeEstimates _backend;
final _prepared = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);

Future<TestDeps> _signedIn(WidgetTester tester, {bool android = false}) async {
  final auth = FakeAuthService();
  final deps = await TestDeps.create(
    auth: auth,
    cloud: FakeCloud(),
    analysis: android ? const NoPhotoRecognitionService() : null,
    photoEstimates: _backend,
    preparePhoto: (_) async => _prepared,
  );
  auth.signIn(_alice);
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(deps.session.isAccount, isTrue);
  await deps.pumpApp(tester);
  return deps;
}

Future<void> _pickPhoto(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('log-meal-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Photo library'));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  // Centred, so a target never ends up under the editor's floating header or bottom bar.
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _row(String name) => find.ancestor(of: find.text(name), matching: find.byType(PhotoEstimateRow));

void main() {
  setUp(() => _backend = _FakeEstimates());

  testWidgets('the first photo asks before anything is uploaded; declining uploads nothing', (tester) async {
    await _signedIn(tester);
    await _pickPhoto(tester);

    expect(find.text('Get a photo estimate?'), findsOneWidget);
    expect(find.textContaining('leaves your phone'), findsOneWidget);
    expect(find.textContaining('Google'), findsWidgets);
    expect(find.textContaining('improve its products'), findsOneWidget);
    expect(
      find.textContaining('calories and protein then come from food data, not from the AI'),
      findsOneWidget,
      reason: 'the AI never gives calories',
    );
    expect(find.textContaining('Nutriq’s server doesn’t keep the photo'), findsOneWidget);
    await _tapVisible(tester, find.text('Keep photos on this phone'));

    expect(_backend.sent, isEmpty);
    expect(find.text('Photo estimate ready'), findsNothing);
  });

  testWidgets('agreeing uploads only the prepared copy and shows an editable estimate', (tester) async {
    final deps = await _signedIn(tester);
    await _pickPhoto(tester);
    await _tapVisible(tester, find.text('Send photos for estimates'));

    expect(_backend.sent.single, _prepared);
    expect(find.text('Photo estimate ready'), findsOneWidget);
    expect(find.textContaining('≈ 377 kcal'), findsOneWidget);
    await tester.tap(find.text('Photo estimate ready'));
    await tester.pumpAndSettle();

    expect(find.text('Photo estimate'), findsOneWidget);
    expect(find.textContaining('Looks like: Tuna and rice'), findsOneWidget);
    expect(find.textContaining('≈ 377 kcal · 8 g protein'), findsOneWidget);
    expect(find.textContaining('Nutriq food list: White rice, cooked'), findsOneWidget);
    expect(
      find.textContaining('USDA FoodData Central (SR Legacy): Fish, tuna, light, canned in oil, drained solids'),
      findsOneWidget,
      reason: 'the matched USDA food and its data type are shown',
    );
    expect(find.textContaining('Estimated from photo (250–330 g)'), findsOneWidget);
    expect(find.textContaining('No nutrition data found'), findsOneWidget);
    expect(find.text('Possible ingredients'), findsOneWidget);
    expect(
      find.descendant(of: _row('Brown sauce'), matching: find.text('Possible ingredient — not counted yet')),
      findsOneWidget,
      reason: 'a hidden ingredient is never counted until the person includes it',
    );
    expect(find.textContaining('Oil from the can may be on the rice'), findsOneWidget);
    expect(find.text('Egg, fried'), findsNothing);
    expect(deps.log.meals, isEmpty, reason: 'nothing is logged by scanning');
  });

  testWidgets('editing amounts, removing and adding — then nothing is logged until “Log meal”', (tester) async {
    final deps = await _signedIn(tester);
    await _pickPhoto(tester);
    await _tapVisible(tester, find.text('Send photos for estimates'));
    await tester.tap(find.text('Photo estimate ready'));
    await tester.pumpAndSettle();

    // Rice: 290 g → 300 g is the person's amount now.
    await _tapVisible(tester, find.descendant(of: _row('Kanin'), matching: find.byIcon(Icons.add_rounded)));
    expect(find.descendant(of: _row('Kanin'), matching: find.text('Your amount')), findsOneWidget);
    expect(find.textContaining('≈ 390 kcal'), findsWidgets);

    // Tuna has no amount from the photo: the person chooses one, starting from 100 g.
    final tuna = _row('Tuna, canned in oil, drained');
    await _tapVisible(tester, find.descendant(of: tuna, matching: find.text('Choose amount')));
    expect(find.textContaining('≈ 588 kcal'), findsOneWidget);
    expect(find.descendant(of: tuna, matching: find.textContaining('Starting amount')), findsOneWidget);
    expect(
      find.descendant(of: tuna, matching: find.text('Your amount')),
      findsNothing,
      reason: '100 g is a starting point, not the person’s amount',
    );

    // The sauce has no nutrition data: remove it.
    await _tapVisible(tester, find.descendant(of: _row('Brown sauce'), matching: find.byTooltip('Remove')));
    expect(_row('Brown sauce'), findsNothing);

    await _tapVisible(tester, find.text('Add 2 foods to meal'));
    expect(find.text('Photo estimate'), findsNothing);
    expect(deps.log.meals, isEmpty);

    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    final meal = deps.log.meals.single;
    expect(meal.source, MealSource.scan);
    expect(meal.items.map((i) => (i.name, i.servingLabel, i.caloriesPerServing)), [
      ('White rice, cooked', '300 g', 390.0),
      ('Tuna, canned in oil, drained', '100 g', 198.0),
    ]);
  });

  testWidgets('several possible USDA matches: nothing is counted until the person picks one', (tester) async {
    Map<String, Object?> usda(int id, String description, num kcal, num protein) => {
      'fdcId': id,
      'description': description,
      'dataType': 'SR Legacy',
      'kcal': kcal,
      'protein': protein,
      'carbs': null,
      'fat': null,
    };
    const breast = 'Chicken, broilers or fryers, breast, meat only, fried';
    const wing = 'Chicken, broilers or fryers, wing, meat and skin, fried';
    _backend.response = {
      'isFood': true,
      'dish': 'Chicken and rice',
      'dishAlternatives': <String>[],
      'foods': [
        {
          'name': 'white rice, cooked',
          'localName': 'kanin',
          'visibility': 'visible',
          'grams': {'low': 250, 'high': 330, 'note': 'about 2 cups'},
          'fdc': null,
          'fdcOptions': <Object?>[],
        },
        {
          'name': 'battered chicken',
          'localName': null,
          'visibility': 'visible',
          'grams': {'low': 120, 'high': 160, 'note': 'one piece'},
          'fdc': null,
          'fdcOptions': [usda(171477, breast, 187, 33.4), usda(171482, wing, 321, 26.1)],
        },
      ],
      'uncertainties': <String>[],
      'remaining': 9,
      'nutritionLookup': 'fdc',
    };
    final deps = await _signedIn(tester);
    await _pickPhoto(tester);
    await _tapVisible(tester, find.text('Send photos for estimates'));
    expect(find.textContaining('≈ 377 kcal'), findsOneWidget, reason: 'only the rice is counted');
    await tester.tap(find.text('Photo estimate ready'));
    await tester.pumpAndSettle();

    final chicken = _row('Battered chicken');
    expect(
      find.descendant(of: chicken, matching: find.textContaining('Several USDA foods could match')),
      findsOneWidget,
    );
    expect(find.descendant(of: chicken, matching: find.text(breast)), findsOneWidget);
    expect(find.descendant(of: chicken, matching: find.text(wing)), findsOneWidget);
    expect(find.textContaining('≈ 377 kcal · 8 g protein'), findsOneWidget);
    expect(find.textContaining('1 food isn’t counted yet'), findsOneWidget);

    await _tapVisible(tester, find.descendant(of: chicken, matching: find.text(wing)));
    expect(find.textContaining('USDA FoodData Central (SR Legacy), your pick: $wing'), findsOneWidget);
    expect(find.textContaining('≈ 826 kcal'), findsOneWidget, reason: '377 + 140 g × 321 / 100');
    expect(find.descendant(of: chicken, matching: find.text('Estimated from photo (120–160 g)')), findsOneWidget);

    // Wrong one — change it.
    await _tapVisible(tester, find.descendant(of: chicken, matching: find.text('Change')));
    expect(find.textContaining('≈ 377 kcal · 8 g protein'), findsOneWidget);
    await _tapVisible(tester, find.descendant(of: chicken, matching: find.text(breast)));
    expect(find.textContaining('≈ 639 kcal'), findsOneWidget, reason: '377 + 140 g × 187 / 100');

    await _tapVisible(tester, find.text('Add 2 foods to meal'));
    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    expect(deps.log.meals.single.items.map((i) => (i.name, i.servingLabel, i.caloriesPerServing)), [
      ('White rice, cooked', '290 g', 377.0),
      ('Battered chicken', '140 g', 261.8),
    ]);
  });

  testWidgets('an ambiguous food can be switched to one of its alternatives', (tester) async {
    _backend.response = {
      'isFood': true,
      'dish': 'Adobo with rice',
      'dishAlternatives': <String>[],
      'foods': [
        {
          'name': 'chicken adobo',
          'localName': null,
          'visibility': 'visible',
          'alternatives': ['pork adobo', 'humba'],
          'grams': {'low': 150, 'high': 210, 'note': 'one bowl'},
          'fdc': null,
          'fdcOptions': <Object?>[],
        },
      ],
      'uncertainties': <String>[],
      'remaining': 9,
      'nutritionLookup': 'fdc',
    };
    final deps = await _signedIn(tester);
    await _pickPhoto(tester);
    await _tapVisible(tester, find.text('Send photos for estimates'));
    await tester.tap(find.text('Photo estimate ready'));
    await tester.pumpAndSettle();

    final row = find.byType(PhotoEstimateRow);
    expect(find.descendant(of: row, matching: find.text('Could also be')), findsOneWidget);
    expect(find.textContaining('Nutriq food list: Chicken adobo'), findsOneWidget);
    expect(find.textContaining('≈ 360 kcal'), findsWidgets, reason: '180 g × 200 kcal / 100 g');

    await _tapVisible(tester, find.descendant(of: row, matching: find.text('Pork adobo')));
    expect(find.textContaining('Nutriq food list: Pork adobo'), findsOneWidget);
    expect(find.textContaining('≈ 522 kcal'), findsWidgets, reason: 'same 180 g, pork adobo values');
    expect(find.descendant(of: row, matching: find.text('Estimated from photo (150–210 g)')), findsOneWidget);

    await _tapVisible(tester, find.descendant(of: row, matching: find.text('Humba')));
    expect(find.textContaining('No nutrition data found'), findsOneWidget, reason: 'not in the food list → no guess');
    expect(find.text('No nutrition counted yet'), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Find')), findsOneWidget);

    await _tapVisible(tester, find.descendant(of: row, matching: find.text('Chicken adobo')));
    await _tapVisible(tester, find.text('Add 1 food to meal'));
    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    expect(deps.log.meals.single.items.map((i) => (i.name, i.servingLabel)), [('Chicken adobo', '180 g')]);
  });

  testWidgets('hidden ingredients aren’t in the total on Today', (tester) async {
    _backend.response = {
      'isFood': true,
      'dish': 'Rice',
      'dishAlternatives': <String>[],
      'foods': [
        {
          'name': 'white rice, cooked',
          'localName': 'kanin',
          'visibility': 'visible',
          'grams': {'low': 250, 'high': 330, 'note': ''},
          'fdc': null,
        },
        {'name': 'cooking oil', 'localName': null, 'visibility': 'inferred', 'grams': null, 'fdc': null},
      ],
      'uncertainties': <String>[],
      'remaining': 9,
      'nutritionLookup': 'fdc',
    };
    await _signedIn(tester);
    await _pickPhoto(tester);
    await _tapVisible(tester, find.text('Send photos for estimates'));

    expect(find.textContaining('≈ 377 kcal'), findsOneWidget, reason: 'rice only — the oil isn’t confirmed');
  });

  testWidgets('a food without nutrition data can be looked up instead', (tester) async {
    await _signedIn(tester);
    await _pickPhoto(tester);
    await _tapVisible(tester, find.text('Send photos for estimates'));
    await tester.tap(find.text('Photo estimate ready'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.descendant(of: _row('Brown sauce'), matching: find.text('Include in estimate')));
    await _tapVisible(tester, find.descendant(of: _row('Brown sauce'), matching: find.text('Find')));
    expect(find.widgetWithText(TextField, 'brown sauce'), findsOneWidget);
  });

  testWidgets('if the estimate fails, the review still works and says why', (tester) async {
    _backend.error = const PhotoEstimateException(PhotoEstimateFailure.offline);
    await _signedIn(tester);
    await _pickPhoto(tester);
    await _tapVisible(tester, find.text('Send photos for estimates'));

    expect(find.textContaining('Couldn’t reach Nutriq’s server'), findsOneWidget);
    expect(
      find.textContaining('wasn’t sent'),
      findsNothing,
      reason: 'it may have been sent before the connection dropped',
    );
    expect(find.text('Photo estimate ready'), findsNothing);
  });

  testWidgets('logging while estimated foods are still waiting asks first', (tester) async {
    final deps = await _signedIn(tester);
    await _pickPhoto(tester);
    await _tapVisible(tester, find.text('Send photos for estimates'));
    await tester.tap(find.text('Photo estimate ready'));
    await tester.pumpAndSettle();

    // Replace the unmatched sauce with a food from the list; rice is still waiting in the estimate.
    await _tapVisible(tester, find.descendant(of: _row('Brown sauce'), matching: find.text('Include in estimate')));
    await _tapVisible(tester, find.descendant(of: _row('Brown sauce'), matching: find.text('Find')));
    await tester.enterText(find.widgetWithText(TextField, 'brown sauce'), 'soy sauce');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soy sauce').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to meal'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    expect(find.text('Photo estimate not added'), findsOneWidget);
    expect(find.textContaining('1 food from the photo estimate isn’t in this meal yet'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deps.log.meals, isEmpty, reason: 'nothing is logged while estimated foods are waiting');
    expect(find.text('Add 1 food to meal'), findsOneWidget);

    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log without them'));
    await tester.pumpAndSettle();
    expect(deps.log.meals.single.items.map((i) => i.name), ['Soy sauce']);
  });

  testWidgets('when no food could be counted, no calorie number is shown', (tester) async {
    _backend.response = {
      'isFood': true,
      'dish': 'Tuna and rice',
      'dishAlternatives': <String>[],
      'foods': [
        {'name': 'brown sauce', 'localName': null, 'visibility': 'visible', 'grams': null, 'fdc': null},
      ],
      'uncertainties': <String>[],
      'remaining': 9,
      'nutritionLookup': 'fdc',
    };
    await _signedIn(tester);
    await _pickPhoto(tester);
    await _tapVisible(tester, find.text('Send photos for estimates'));

    expect(find.text('Photo estimate ready'), findsOneWidget);
    expect(find.textContaining('≈ 0 kcal'), findsNothing);
    await tester.tap(find.text('Photo estimate ready'));
    await tester.pumpAndSettle();
    expect(find.text('No nutrition counted yet'), findsOneWidget);
    expect(find.textContaining('≈ 0 kcal'), findsNothing);
  });

  testWidgets('with photo estimates on, the camera tips don’t claim the photo stays on the phone', (tester) async {
    final deps = await _signedIn(tester);
    await deps.session.photoAnalysis.setCloudEnabled(true);
    await deps.pumpPushed(tester, CameraScreen(loadCameras: () async => const <CameraDescription>[]));

    await tester.tap(find.byTooltip('Photo tips'));
    await tester.pumpAndSettle();

    expect(find.textContaining('never uploaded'), findsNothing);
    expect(find.textContaining('is sent to Google’s Gemini'), findsOneWidget);
  });

  testWidgets('Android: no photo recognition until cloud estimates are switched on in Settings', (tester) async {
    await _signedIn(tester, android: true);
    await tester.tap(find.byKey(const ValueKey('log-meal-button')));
    await tester.pumpAndSettle();
    expect(find.text('Take photo'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    final row = find.text('Cloud photo estimates');
    await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
    final toggle = find.descendant(
      of: find.ancestor(of: row, matching: find.byType(NqRow)),
      matching: find.byWidgetPredicate((w) => w is Switch || w is CupertinoSwitch),
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Get a photo estimate?'), findsOneWidget);
    await _tapVisible(tester, find.text('Send photos for estimates'));

    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('log-meal-button')));
    await tester.pumpAndSettle();
    expect(find.text('Scan food'), findsOneWidget);
  });
}
