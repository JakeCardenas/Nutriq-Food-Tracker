import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/nutrition.dart';
import 'package:nutriq/domain/models/user_profile.dart';
import 'package:nutriq/services/coach/coach_service.dart';
import 'package:nutriq/services/coach/demo_coach_service.dart';

CoachContext _ctx({
  UserProfile? profile = const UserProfile(
    age: 30,
    goal: FitnessGoal.buildStrength,
    calorieGoal: CalorieRange(min: 2200, max: 2400),
    proteinTargetG: 130,
    workoutDaysPerWeek: 3,
  ),
  NutritionTotals today = const NutritionTotals(calories: 1200, protein: 62, carbs: 140, fat: 40),
  int meals = 2,
  List<DaySummary> recent = const [],
}) => CoachContext(
  profile: profile,
  today: today,
  todayMealCount: meals,
  recentDays: recent,
  now: DateTime(2026, 10, 6, 18),
);

void main() {
  final coach = DemoCoachService(replyDelay: Duration.zero);

  Future<CoachReply> ask(String q, [CoachContext? c]) => coach.reply(message: q, context: c ?? _ctx());

  group('intents', () {
    test('protein question uses logged totals and the reference', () async {
      final r = await ask('How am I doing with my protein today?');
      expect(r.kind, CoachReplyKind.answer);
      expect(r.text, contains('62'));
      expect(r.text, contains('130'));
    });

    test('protein question with nothing logged asks to log first', () async {
      final r = await ask('how is my protein', _ctx(today: NutritionTotals.zero, meals: 0));
      expect(r.text.toLowerCase(), contains('log'));
    });

    test('dinner idea mentions the goal', () async {
      final r = await ask('Suggest a balanced dinner for my goal.');
      expect(r.kind, CoachReplyKind.answer);
      expect(r.text.toLowerCase(), contains('strength'));
    });

    test('weekly review summarises logged days', () async {
      final days = List.generate(
        7,
        (i) => DaySummary(
          day: DateTime(2026, 9, 30 + i),
          totals: i.isEven ? const NutritionTotals(calories: 2300, protein: 120) : NutritionTotals.zero,
          mealCount: i.isEven ? 3 : 0,
        ),
      );
      final r = await ask('What can I improve this week?', _ctx(recent: days));
      expect(r.text, contains('4 of the last 7 days'));
    });

    test('strength consistency uses workout days', () async {
      final r = await ask('Help me stay consistent with strength training.');
      expect(r.text, contains('3'));
    });

    test('unknown topics fall back to a list of what the demo can do', () async {
      final r = await ask('what is the capital of France');
      expect(r.kind, CoachReplyKind.fallback);
      expect(r.text.toLowerCase(), contains('protein'));
    });

    test('every reply is labeled demo', () async {
      for (final q in ['protein?', 'dinner idea', 'hello', 'purge']) {
        expect((await ask(q)).isDemo, isTrue, reason: q);
      }
    });
  });

  group('safety', () {
    test('extreme restriction is declined', () async {
      final r = await ask('I want to eat 600 calories a day');
      expect(r.kind, CoachReplyKind.safety);
    });

    test('eating-disorder cues get a supportive referral', () async {
      final r = await ask('how do I purge after eating');
      expect(r.kind, CoachReplyKind.safety);
      expect(r.text.toLowerCase(), contains('support'));
    });

    test('diagnosis questions are deferred to a professional', () async {
      final r = await ask('do I have diabetes?');
      expect(r.kind, CoachReplyKind.medical);
    });

    test('guaranteed predictions are not made', () async {
      final r = await ask('how fast will I lose 10 kg');
      expect(r.kind, CoachReplyKind.prediction);
    });

    test('under-18 users get no weight-loss coaching', () async {
      final r = await ask(
        'how do I lose weight fast',
        _ctx(profile: const UserProfile(age: 16, goal: FitnessGoal.loseFat)),
      );
      expect(r.kind, CoachReplyKind.safety);
      expect(r.text, contains('under 18'));
    });

    test('health considerations get no weight-loss targets', () async {
      final r = await ask(
        'how many calories should I cut to lose fat',
        _ctx(profile: const UserProfile(age: 30, health: {HealthConsideration.pregnant})),
      );
      expect(r.kind, CoachReplyKind.safety);
      expect(r.text.toLowerCase(), contains('professional'));
    });

    test('ordinary adult weight questions are not blocked', () async {
      final r = await ask(
        'Suggest a dinner to help me lose fat',
        _ctx(profile: const UserProfile(age: 30, goal: FitnessGoal.loseFat)),
      );
      expect(r.kind, CoachReplyKind.answer);
    });
  });

  group('insight', () {
    test('nothing logged nudges first meal', () {
      final i = coach.insight(_ctx(today: NutritionTotals.zero, meals: 0));
      expect(i.text.toLowerCase(), contains('first meal'));
    });

    test('low protein in the evening suggests a protein-forward meal', () {
      final i = coach.insight(_ctx(today: const NutritionTotals(calories: 900, protein: 40), meals: 2));
      expect(i.text.toLowerCase(), contains('protein'));
      expect(i.suggestedPrompt, isNotEmpty);
    });

    test('minors never get calorie-range insights', () {
      final i = coach.insight(_ctx(profile: const UserProfile(age: 15)));
      expect(i.text.toLowerCase(), isNot(contains('range')));
    });
  });
}
