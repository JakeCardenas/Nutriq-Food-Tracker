import 'coach_service.dart';

/// Guardrails every coach reply passes through first — demo or real.
///
/// The coach must not diagnose, prescribe, encourage extreme restriction,
/// promise results, or give dieting advice to minors or to people who
/// reported pregnancy, breastfeeding, or a relevant medical condition.
abstract final class CoachSafety {
  static final _eatingDisorderCue = RegExp(
    r"\b(purg(e|ing)|throw(ing)? up|make myself (sick|vomit)|vomit\w*|laxatives?|starv(e|ing)|"
    r"stop eating|not eat(ing)? (for|at all)|binge\w*)\b",
  );
  static final _calorieNumber = RegExp(r'(\d{2,4})\s*(k?cals?\b|calories?\b)');
  static final _intakeWords = RegExp(r"\b(a day|per day|each day|daily|eat|diet|only|limit|stay under|target)\b");
  static final _fasting = RegExp(r"\b((water|dry|juice) fast\w*|fast(ing)? for \d+ days?|skip (all|every) meals?)\b");
  static final _rapidLoss = RegExp(
    r"\blose (\d+(?:\.\d+)?)\s*(lbs?|pounds|kgs?|kilos?) in (a|one|two|\d+) (days?|weeks?)\b",
  );
  static final _medical = RegExp(
    r"\b(diagnos\w*|do i have|symptoms?|medication|medicine|insulin|metformin|dose|dosage|"
    r"blood (sugar|pressure)|cholesterol|disease|prescri\w*|diabet\w*|thyroid)\b",
  );
  static final _prediction = RegExp(
    r"\b(how (long|fast|quickly|soon)|will i (lose|gain|drop|get)|when will i|guarantee\w*|"
    r"how many (days|weeks|months))\b",
  );
  static final _bodyWords = RegExp(r"\b(lose|gain|drop|weight|kg|kgs|lbs?|pounds|abs|muscle|fat)\b");
  static final _weightLossIntent = RegExp(
    r"\b(los(e|ing)|lost|drop) (weight|fat|pounds|lbs|kg|kilos)|\bcut(ting)?\b|deficit|"
    r"\bdiet(ing)?\b|slim\w*|burn fat|skinny|lean out|calories should i (eat|cut)",
  );

  /// Returns a safety reply when [message] must not get a normal answer.
  static CoachReply? check(String message, CoachContext context, {required bool isDemo}) {
    final m = message.toLowerCase();
    CoachReply reply(CoachReplyKind kind, String text) => CoachReply(text: text, kind: kind, isDemo: isDemo);

    if (_eatingDisorderCue.hasMatch(m)) {
      return reply(
        CoachReplyKind.safety,
        'It sounds like this might be about more than tracking food, and you deserve real support '
        'with it. I’m not able to help with that safely. Please consider reaching out to a doctor, '
        'a registered dietitian, or an eating-disorder support line in your area. If you feel unsafe '
        'right now, contact local emergency services.',
      );
    }

    if (_isExtremeRestriction(m)) {
      return reply(
        CoachReplyKind.safety,
        'I can’t help plan very low intakes or very fast weight loss — they can be risky and are hard '
        'to keep up. A gentler approach tends to work better: regular meals, plenty of protein and '
        'vegetables, and a modest range you can sustain. For a specific target, a doctor or registered '
        'dietitian can help.',
      );
    }

    if (_medical.hasMatch(m)) {
      return reply(
        CoachReplyKind.medical,
        'I can’t diagnose conditions or advise on medication or treatment — a doctor or registered '
        'dietitian is the right person for that. I can still help with general things like meal '
        'ideas and staying consistent with logging.',
      );
    }

    if (_prediction.hasMatch(m) && _bodyWords.hasMatch(m)) {
      return reply(
        CoachReplyKind.prediction,
        'I can’t predict exact results — bodies respond differently, and Nutriq’s numbers are '
        'estimates. What tends to help is consistency: logging most days, a steady range, enough '
        'protein, and regular training. Trends over a few weeks tell you more than any prediction.',
      );
    }

    final profile = context.profile;
    if (profile != null && _weightLossIntent.hasMatch(m)) {
      if (profile.isMinor) {
        return reply(
          CoachReplyKind.safety,
          'Nutriq doesn’t give weight-loss or dieting advice to people under 18. Growing bodies need '
          'steady energy, and the right approach depends on you — a doctor, school nurse, or trusted '
          'adult can help with questions about weight. I’m happy to help with balanced meals, eating '
          'regularly, or fueling sports.',
        );
      }
      if (profile.hasHealthConsideration) {
        return reply(
          CoachReplyKind.safety,
          'Because you noted pregnancy, breastfeeding, or a medical condition, I won’t suggest '
          'weight-loss targets — general formulas may not fit your needs. A doctor or registered '
          'dietitian is the right professional to set one, and you can add it in Settings. I can '
          'still help with balanced meal ideas and consistent logging.',
        );
      }
    }
    return null;
  }

  static bool _isExtremeRestriction(String m) {
    if (_fasting.hasMatch(m)) return true;
    for (final match in _calorieNumber.allMatches(m)) {
      final kcal = int.parse(match.group(1)!);
      if (kcal < 1000 && _intakeWords.hasMatch(m)) return true;
    }
    final loss = _rapidLoss.firstMatch(m);
    if (loss != null) {
      var kg = double.parse(loss.group(1)!);
      if (loss.group(2)!.startsWith('lb') || loss.group(2) == 'pounds') kg *= 0.4536;
      final countWord = loss.group(3)!;
      final count = switch (countWord) {
        'a' || 'one' => 1,
        'two' => 2,
        _ => int.parse(countWord),
      };
      final weeks = loss.group(4)!.startsWith('day') ? count / 7 : count.toDouble();
      if (weeks <= 0 || kg / weeks > 1) return true;
    }
    return false;
  }
}
