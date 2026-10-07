import 'dart:convert';
import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../domain/models/food_item.dart';
import '../../domain/models/meal.dart';
import '../../domain/models/nutrition.dart';
import 'coach_service.dart';

/// What the AI coach is sent: the chat so far and a *minimal* summary of the
/// person's goals and log. Never photos, notes, Apple Health data, exact age,
/// sex or height; under-18s send no body weight at all.
abstract final class CoachPayload {
  static const maxTurns = 16;
  static const maxMessageChars = 2000;

  /// The server refuses context larger than 20,000 characters.
  static const maxContextChars = 18000;

  static Map<String, Object?> build({
    required String message,
    required CoachContext context,
    List<ChatMessage> history = const [],
  }) {
    final question = message.trim();
    final endsWithQuestion =
        history.isNotEmpty && history.last.role == ChatRole.user && history.last.text.trim() == question;
    final chat = endsWithQuestion ? history : [...history, ChatMessage(role: ChatRole.user, text: question)];
    return {
      'messages': [
        for (final m in chat.skip(math.max(0, chat.length - maxTurns)))
          if (m.text.trim().isNotEmpty)
            {'role': m.role == ChatRole.user ? 'user' : 'assistant', 'content': _clip(m.text.trim(), maxMessageChars)},
      ],
      'context': contextJson(context),
    };
  }

  static Map<String, Object?> contextJson(CoachContext c) {
    var json = _context(c, meals: 10, items: 8, saved: 20);
    if (jsonEncode(json).length >= maxContextChars) json = _context(c, meals: 10, items: 4, saved: 0);
    if (jsonEncode(json).length >= maxContextChars) json = _context(c, meals: 4, items: 3, saved: 0);
    return json;
  }

  static Map<String, Object?> _context(CoachContext c, {required int meals, required int items, required int saved}) {
    final day = DateFormat('yyyy-MM-dd', 'en_US');
    final time = DateFormat('HH:mm', 'en_US');
    final p = c.profile;
    final restriction = p == null
        ? null
        : p.isMinor
        ? 'minor'
        : p.hasHealthConsideration
        ? 'health'
        : null;
    return {
      'localDate': day.format(c.now),
      'localTime': time.format(c.now),
      'weekday': DateFormat('EEEE', 'en_US').format(c.now),
      'units': c.units.name,
      'profile': p == null
          ? null
          : {
              if (p.goal != null) 'goal': p.goal!.title,
              if (p.age != null) 'ageGroup': p.isMinor ? 'under 18' : '18+',
              'restriction': ?restriction,
              if (p.activity != null) 'activity': p.activity!.title,
              if (p.workoutDaysPerWeek != null) 'workoutDaysPerWeek': p.workoutDaysPerWeek,
              if (!p.isMinor && p.weightKg != null) 'weightKg': _oneDecimal(p.weightKg!),
              if (restriction == null && p.goalWeightKg != null) 'goalWeightKg': _oneDecimal(p.goalWeightKg!),
              if (p.calorieGoal != null) 'calorieGoal': {'min': p.calorieGoal!.min, 'max': p.calorieGoal!.max},
              if (p.proteinTargetG != null) 'proteinTargetG': p.proteinTargetG,
            },
      'todayTotals': _totals(c.today),
      'todayMeals': [
        for (final m in c.todayMeals.skip(math.max(0, c.todayMeals.length - meals))) _meal(m, time, items),
      ],
      'recentDays': [
        for (final d in c.recentDays) {'date': day.format(d.day), 'meals': d.mealCount, ..._totals(d.totals)},
      ],
      'savedFoods': [
        for (final f in c.savedFoods.take(saved))
          {
            'name': _clip(f.name, 48),
            'serving': _clip(f.servingLabel, 24),
            'kcal': f.caloriesPerServing.round(),
            'protein': f.proteinPerServing.round(),
          },
      ],
    };
  }

  static Map<String, Object?> _meal(Meal m, DateFormat time, int items) => {
    'time': time.format(m.loggedAt),
    'title': _clip(m.title, 48),
    'items': [for (final i in m.items.take(items)) _item(i)],
    if (m.items.length > items) 'moreItems': m.items.length - items,
  };

  static Map<String, Object?> _item(FoodItem i) => {
    'name': _clip(i.name, 48),
    'servings': (i.servings * 100).round() / 100,
    'serving': _clip(i.servingLabel, 24),
    ..._totals(i.totals),
  };

  static Map<String, Object?> _totals(NutritionTotals t) => {
    'kcal': t.calories.round(),
    'protein': t.protein.round(),
    'carbs': t.carbs.round(),
    'fat': t.fat.round(),
  };

  static double _oneDecimal(double v) => (v * 10).round() / 10;

  /// Cuts to at most [max] UTF-16 units without splitting an emoji.
  static String _clip(String s, int max) {
    if (s.length <= max) return s;
    var cut = s.substring(0, max);
    final last = cut.codeUnitAt(cut.length - 1);
    if (last >= 0xD800 && last <= 0xDBFF) cut = cut.substring(0, cut.length - 1);
    return cut;
  }
}
