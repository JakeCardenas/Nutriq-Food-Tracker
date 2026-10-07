import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/food_item.dart';
import 'package:nutriq/domain/models/meal.dart';
import 'package:nutriq/domain/models/nutrition.dart';
import 'package:nutriq/domain/models/user_profile.dart';
import 'package:nutriq/domain/units.dart';
import 'package:nutriq/services/coach/coach_payload.dart';
import 'package:nutriq/services/coach/coach_service.dart';

const _adult = UserProfile(
  age: 34,
  sex: SexForEstimate.female,
  heightCm: 168,
  weightKg: 70.24,
  goalWeightKg: 65,
  activity: ActivityLevel.moderate,
  goal: FitnessGoal.buildStrength,
  workoutDaysPerWeek: 3,
  calorieGoal: CalorieRange(min: 2000, max: 2200),
  proteinTargetG: 130,
);

Meal _meal(String id, DateTime at, List<FoodItem> items, {String? name}) => Meal(
  id: id,
  loggedAt: at,
  type: MealType.lunch,
  source: MealSource.manual,
  items: items,
  photoPath: 'meal_photos/$id.jpg',
  note: 'private note',
  name: name,
);

CoachContext _ctx({UserProfile? profile = _adult, List<Meal> meals = const [], List<FoodItem> saved = const []}) =>
    CoachContext(
      profile: profile,
      today: const NutritionTotals(calories: 1234.6, protein: 61.6, carbs: 140.2, fat: 40.4),
      todayMealCount: meals.length,
      recentDays: [
        DaySummary(
          day: DateTime(2026, 10, 6),
          totals: const NutritionTotals(calories: 2100, protein: 120, carbs: 230, fat: 70),
          mealCount: 3,
        ),
      ],
      now: DateTime(2026, 10, 7, 18, 40),
      todayMeals: meals,
      savedFoods: saved,
      units: UnitSystem.imperial,
    );

void main() {
  group('context', () {
    test('summarises goals, today, recent days and saved foods with rounded numbers', () {
      final lunch = _meal('m1', DateTime(2026, 10, 7, 12, 30), const [
        FoodItem(id: 'i1', name: 'Chicken rice bowl', caloriesPerServing: 650.4, proteinPerServing: 40.2),
      ], name: 'Lunch out');
      final json = CoachPayload.contextJson(
        _ctx(
          meals: [lunch],
          saved: const [FoodItem(id: 's1', name: 'Greek yogurt', servingLabel: '1 cup', caloriesPerServing: 150)],
        ),
      );

      expect(json['localDate'], '2026-10-07');
      expect(json['localTime'], '18:40');
      expect(json['weekday'], 'Wednesday');
      expect(json['units'], 'imperial');
      final profile = json['profile'] as Map;
      expect(profile['goal'], 'Build strength');
      expect(profile['ageGroup'], '18+');
      expect(profile['weightKg'], 70.2);
      expect(profile['goalWeightKg'], 65.0);
      expect(profile['calorieGoal'], {'min': 2000, 'max': 2200});
      expect(profile['proteinTargetG'], 130);
      expect(profile.containsKey('restriction'), isFalse);
      expect(json['todayTotals'], {'kcal': 1235, 'protein': 62, 'carbs': 140, 'fat': 40});
      final meal = (json['todayMeals'] as List).single as Map;
      expect(meal['time'], '12:30');
      expect(meal['title'], 'Lunch out');
      expect((meal['items'] as List).single, containsPair('name', 'Chicken rice bowl'));
      expect((meal['items'] as List).single, containsPair('kcal', 650));
      expect((json['recentDays'] as List).single, {
        'date': '2026-10-06',
        'meals': 3,
        'kcal': 2100,
        'protein': 120,
        'carbs': 230,
        'fat': 70,
      });
      expect((json['savedFoods'] as List).single, containsPair('name', 'Greek yogurt'));
    });

    test('never includes exact age, sex, height, photos or notes', () {
      final text = jsonEncode(
        CoachPayload.contextJson(
          _ctx(
            meals: [
              _meal('m1', DateTime(2026, 10, 7, 12), const [FoodItem(id: 'i', name: 'Soup', caloriesPerServing: 200)]),
            ],
          ),
        ),
      );
      expect(text, isNot(contains('34')));
      expect(text, isNot(contains('female')));
      expect(text, isNot(contains('168')));
      expect(text, isNot(contains('photo')));
      expect(text, isNot(contains('private note')));
    });

    test('under-18s: flagged as restricted, no body weight sent', () {
      final json = CoachPayload.contextJson(_ctx(profile: const UserProfile(age: 16, weightKg: 55, goalWeightKg: 50)));
      final profile = json['profile'] as Map;
      expect(profile['ageGroup'], 'under 18');
      expect(profile['restriction'], 'minor');
      expect(profile.containsKey('weightKg'), isFalse);
      expect(profile.containsKey('goalWeightKg'), isFalse);
    });

    test('health considerations: flagged as restricted, no goal weight sent', () {
      final json = CoachPayload.contextJson(
        _ctx(
          profile: const UserProfile(age: 30, weightKg: 70, goalWeightKg: 60, health: {HealthConsideration.pregnant}),
        ),
      );
      final profile = json['profile'] as Map;
      expect(profile['restriction'], 'health');
      expect(profile.containsKey('goalWeightKg'), isFalse);
    });

    test('stays small even with a huge log', () {
      final items = [
        for (var i = 0; i < 30; i++) FoodItem(id: 'i$i', name: 'Food ${'x' * 200} $i', caloriesPerServing: 100),
      ];
      final meals = [for (var m = 0; m < 50; m++) _meal('m$m', DateTime(2026, 10, 7, 8), items)];
      final saved = [
        for (var s = 0; s < 200; s++) FoodItem(id: 's$s', name: 'Saved ${'y' * 200}', caloriesPerServing: 1),
      ];
      final text = jsonEncode(CoachPayload.contextJson(_ctx(meals: meals, saved: saved)));
      expect(text.length, lessThan(CoachPayload.maxContextChars));
    });
  });

  group('messages', () {
    test('sends the chat as user/assistant turns ending with the new question', () {
      final payload = CoachPayload.build(
        message: 'And for dinner?',
        context: _ctx(),
        history: const [
          ChatMessage(role: ChatRole.user, text: 'Hi'),
          ChatMessage(role: ChatRole.coach, text: 'Hello!'),
          ChatMessage(role: ChatRole.user, text: 'And for dinner?'),
        ],
      );
      expect(payload['messages'], [
        {'role': 'user', 'content': 'Hi'},
        {'role': 'assistant', 'content': 'Hello!'},
        {'role': 'user', 'content': 'And for dinner?'},
      ]);
      expect(payload['context'], isA<Map>());
    });

    test('adds the question when the history doesn’t end with it', () {
      final payload = CoachPayload.build(message: 'Protein?', context: _ctx());
      expect(payload['messages'], [
        {'role': 'user', 'content': 'Protein?'},
      ]);
    });

    test('keeps the last 16 messages and clips very long ones', () {
      final history = [
        for (var i = 0; i < 40; i++) ChatMessage(role: i.isEven ? ChatRole.user : ChatRole.coach, text: 'm$i'),
        ChatMessage(role: ChatRole.user, text: 'z' * 5000),
      ];
      final messages = CoachPayload.build(message: 'z' * 5000, context: _ctx(), history: history)['messages'] as List;
      expect(messages, hasLength(16));
      expect((messages.last as Map)['content'], hasLength(CoachPayload.maxMessageChars));
    });
  });
}
