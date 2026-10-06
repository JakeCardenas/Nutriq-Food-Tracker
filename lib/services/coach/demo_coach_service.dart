import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../domain/models/user_profile.dart';
import 'coach_safety.dart';
import 'coach_service.dart';

/// A scripted, rule-based coach for demo builds. It reads the person's real
/// profile and log to fill in numbers, but it is **not** a language model,
/// and the UI labels it that way.
class DemoCoachService implements CoachService {
  DemoCoachService({this.replyDelay = const Duration(milliseconds: 700)});

  final Duration replyDelay;
  static final _n = NumberFormat.decimalPattern();

  @override
  bool get isDemo => true;

  @override
  String get label => 'Demo coach';

  @override
  Future<CoachReply> reply({
    required String message,
    required CoachContext context,
    List<ChatMessage> history = const [],
  }) async {
    if (replyDelay > Duration.zero) await Future<void>.delayed(replyDelay);
    final safety = CoachSafety.check(message, context, isDemo: true);
    if (safety != null) return safety;

    final m = message.toLowerCase();
    CoachReply answer(String text) => CoachReply(text: text, kind: CoachReplyKind.answer, isDemo: true);

    if (RegExp(r'dinner|lunch|breakfast|meal idea|what (should|can) i eat|suggest|recipe|snack')
        .hasMatch(m)) {
      return answer(_mealIdea(context));
    }
    if (m.contains('protein')) return answer(_protein(context));
    if (RegExp(r'week|improve|better|progress|trend').hasMatch(m)) return answer(_week(context));
    if (RegExp(r'strength|lift|gym|train|workout|consisten|routine|motivat').hasMatch(m)) {
      return answer(_strength(context));
    }
    if (RegExp(r'calorie|kcal|left|remaining').hasMatch(m)) return answer(_calories(context));
    if (RegExp(r"^(hi|hello|hey|yo|good (morning|afternoon|evening))\b|^help\b|what can you do")
        .hasMatch(m.trim())) {
      return answer(
        'Hi! I’m Nutriq’s demo coach. I look at what you’ve logged and can help with protein, '
        'meal ideas, your week, and staying consistent. Try one of the suggestions below.',
      );
    }
    return const CoachReply(
      kind: CoachReplyKind.fallback,
      isDemo: true,
      text:
          'I’m a demo coach with a small set of scripted topics, so I can’t answer that well. '
          'I can help with: your protein today, a balanced dinner idea, what to improve this week, '
          'or staying consistent with training.',
    );
  }

  @override
  CoachInsight insight(CoachContext c) {
    final profile = c.profile;
    if (c.todayMealCount == 0) {
      return const CoachInsight(
        text: 'Log your first meal to see how today is shaping up.',
        suggestedPrompt: CoachPrompts.dinner,
      );
    }
    final target = c.restricted ? null : profile?.proteinTargetG;
    if (target != null && c.now.hour >= 14 && c.today.protein < target * 0.5) {
      return CoachInsight(
        text:
            'Protein is at about ${c.today.protein.round()} g of your $target g reference. '
            'A protein-forward next meal would help.',
        suggestedPrompt: CoachPrompts.protein,
      );
    }
    final range = c.restricted ? null : profile?.calorieGoal;
    final kcal = c.today.calories;
    if (range != null) {
      if (range.contains(kcal)) {
        return const CoachInsight(
          text: 'You’re within your range so far — a steady day.',
          suggestedPrompt: CoachPrompts.week,
        );
      }
      if (kcal > range.max) {
        return const CoachInsight(
          text: 'A bit above your range today. One day doesn’t define a trend.',
          suggestedPrompt: CoachPrompts.week,
        );
      }
      if (c.now.hour >= 16) {
        return CoachInsight(
          text:
              'About ${_n.format(range.min - kcal.round())} kcal to the low end of your range. '
              'A balanced dinner could cover it.',
          suggestedPrompt: CoachPrompts.dinner,
        );
      }
    }
    final meals = c.todayMealCount == 1 ? '1 meal' : '${c.todayMealCount} meals';
    return CoachInsight(
      text: '$meals logged · about ${_n.format(kcal.round())} kcal so far. Want a dinner idea?',
      suggestedPrompt: CoachPrompts.dinner,
    );
  }

  String _protein(CoachContext c) {
    if (c.todayMealCount == 0) {
      return 'You haven’t logged any meals today, so I can’t estimate your protein yet. Log a meal '
          'and ask again — I’ll compare it with your reference.';
    }
    final p = c.today.protein.round();
    final target = c.restricted ? null : c.profile?.proteinTargetG;
    if (target == null) {
      return 'You’ve logged about $p g of protein today across ${c.todayMealCount} '
          '${c.todayMealCount == 1 ? 'meal' : 'meals'}. Including a protein source at each meal — '
          'eggs, yogurt, beans, tofu, fish or chicken — is an easy way to keep it steady. '
          'These are estimates from your log.';
    }
    final pct = (p / target * 100).round();
    final left = target - p;
    final tip = left > 0
        ? 'About $left g to go. A palm-sized portion of chicken, fish, tofu or a cup of Greek yogurt '
              'adds roughly 20–30 g.'
        : 'You’ve reached your reference — nice work.';
    return 'So far today you’ve logged about $p g of protein — roughly $pct% of your $target g '
        'reference. $tip These numbers come from your logged estimates, so treat them as approximate.';
  }

  String _mealIdea(CoachContext c) {
    final goal = c.profile?.goal;
    final goalPhrase = goal == null ? 'a balanced day' : 'your goal to ${goal.title.toLowerCase()}';
    if (c.restricted) {
      return 'Here’s a balanced dinner idea for $goalPhrase: fill half the plate with vegetables, '
          'a quarter with protein (fish, chicken, eggs, tofu or beans), a quarter with rice, '
          'potatoes or whole grains, and add a little healthy fat like olive oil or avocado.';
    }
    final idea = switch (goal) {
      FitnessGoal.loseFat =>
        'a big plate of roasted or stir-fried vegetables, one to two palms of lean '
            'protein (chicken, fish, tofu or beans), and a fist of whole grains — roughly 450–600 kcal '
            'and 35–45 g protein',
      FitnessGoal.gainMuscle =>
        'salmon or chicken, a generous portion of rice or potatoes, vegetables, '
            'and some olive oil or avocado — roughly 700–850 kcal and 40–50 g protein',
      FitnessGoal.buildStrength =>
        'lean protein (chicken, lean beef or tofu), a solid portion of rice, '
            'pasta or potatoes to fuel training, and vegetables — roughly 600–750 kcal and about 40 g protein',
      _ =>
        'half a plate of vegetables, a quarter protein, a quarter whole grains or potatoes, plus a '
            'little healthy fat — roughly 500–700 kcal',
    };
    final parts = ['Here’s a dinner idea for $goalPhrase: $idea.'];
    final range = c.profile?.calorieGoal;
    if (range != null) {
      final kcal = c.today.calories.round();
      if (kcal < range.min) {
        parts.add(
          'You have roughly ${_n.format(range.min - kcal)}–${_n.format(range.max - kcal)} kcal '
          'left in your range today.',
        );
      } else if (kcal <= range.max) {
        parts.add(
          'You’re already within your range, so a lighter version — more vegetables, a smaller '
          'grain portion — fits well.',
        );
      } else {
        parts.add(
          'You’re a bit above your range today; a lighter, vegetable-heavy plate fits, and one day '
          'doesn’t define a trend.',
        );
      }
    }
    parts.add('All numbers are rough estimates.');
    return parts.join(' ');
  }

  String _week(CoachContext c) {
    final logged = c.recentDays.where((d) => d.mealCount > 0).toList();
    if (logged.isEmpty) {
      return 'There’s nothing logged in the last 7 days yet. A simple first step: log one meal a day '
          'this week — any meal counts.';
    }
    final avgKcal = logged.map((d) => d.totals.calories).reduce((a, b) => a + b) / logged.length;
    final avgProtein = logged.map((d) => d.totals.protein).reduce((a, b) => a + b) / logged.length;
    final parts = [
      'You logged meals on ${logged.length} of the last 7 days. On those days you averaged about '
          '${_n.format(avgKcal.round())} kcal and ${avgProtein.round()} g protein (estimates).',
    ];
    final range = c.restricted ? null : c.profile?.calorieGoal;
    final target = c.restricted ? null : c.profile?.proteinTargetG;
    var daysAbove = 0;
    if (range != null) {
      final inRange = logged.where((d) => range.contains(d.totals.calories)).length;
      daysAbove = logged.where((d) => d.totals.calories > range.max).length;
      parts.add('$inRange of those days landed in your range.');
    }
    if (logged.length < 5) {
      parts.add(
        'One thing to try: log on ${math.min(logged.length + 2, 7)} days next week — '
        'consistency makes the numbers more useful.',
      );
    } else if (target != null && avgProtein < target * 0.8) {
      parts.add(
        'One thing to try: add a protein source to breakfast — it’s the easiest place to close '
        'the gap to $target g.',
      );
    } else if (daysAbove >= 3) {
      parts.add(
        'One thing to try: plan a simple, lighter dinner for busy days — the pattern matters more '
        'than any single day.',
      );
    } else {
      parts.add('You’re in a good rhythm. Keep it going, and check in like this once a week.');
    }
    return parts.join(' ');
  }

  String _strength(CoachContext c) {
    final days = c.profile?.workoutDaysPerWeek;
    final plan = days != null && days > 0
        ? 'You planned $days training ${days == 1 ? 'day' : 'days'} a week — put them in your calendar '
              'like appointments.'
        : 'Start with 2–3 sessions a week you can realistically keep.';
    return 'Consistency beats intensity. $plan\n'
        '• Have a protein-rich meal within a few hours of training — Greek yogurt, eggs, chicken or tofu.\n'
        '• Spread protein across 3–4 meals instead of one big one.\n'
        '• Keep a simple log of your lifts so progress is visible.\n'
        '• Protect your sleep — it’s when recovery happens.';
  }

  String _calories(CoachContext c) {
    final kcal = c.today.calories.round();
    final logged = 'So far you’ve logged about ${_n.format(kcal)} kcal today (estimate).';
    if (c.restricted) {
      return '$logged Nutriq doesn’t set calorie targets for you, so focus on regular, balanced meals.';
    }
    final range = c.profile?.calorieGoal;
    if (range == null) {
      return '$logged You haven’t set a calorie goal — you can add one in Settings → Goals, or keep '
          'logging without one.';
    }
    final r = '${_n.format(range.min)}–${_n.format(range.max)}';
    if (kcal < range.min) {
      return '$logged Your range is $r, so roughly ${_n.format(range.min - kcal)} kcal to the low end.';
    }
    if (kcal <= range.max) return '$logged That’s within your $r range.';
    return '$logged That’s a little above your $r range — totally fine now and then.';
  }
}
