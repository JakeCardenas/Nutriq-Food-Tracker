import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../state/coach_controller.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/labels.dart';

/// What turning on the AI coach means, shown before it's used.
const aiCoachConsentText =
    'Get real answers about your meals and goals from Claude, an AI model by Anthropic. Each time you ask, Nutriq '
    'sends your question, this chat, your goals and a summary of recent meals (food names with estimated calories '
    'and macros) to Anthropic through Nutriq’s server. Meal photos and Apple Health data are never sent, and chats '
    'aren’t saved. AI can make mistakes and isn’t medical advice. Up to 30 messages a day.';

/// Opt-in card on the Coach screen for signed-in people who haven't chosen yet.
class AiConsentCard extends StatelessWidget {
  const AiConsentCard({super.key, required this.coach});

  final CoachController coach;

  @override
  Widget build(BuildContext context) => NoticeCard(
    icon: Icons.auto_awesome_outlined,
    title: 'Try the AI coach?',
    message: aiCoachConsentText,
    action: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton(
            onPressed: () => coach.setAiEnabled(true),
            style: FilledButton.styleFrom(
              backgroundColor: NqColors.inkSoft,
              foregroundColor: NqColors.onInk,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Turn on AI coach'),
          ),
          TextButton(
            onPressed: () => coach.setAiEnabled(false),
            style: TextButton.styleFrom(foregroundColor: NqColors.ink, visualDensity: VisualDensity.compact),
            child: const Text('Not now'),
          ),
        ],
      ),
    ),
  );
}

/// Settings switch: turning on asks first; turning off doesn't.
Future<void> setAiCoachFromSettings(BuildContext context, CoachController coach, bool on) async {
  if (!on) return coach.setAiEnabled(false);
  final ok = await confirmAction(
    context,
    title: 'Turn on the AI coach?',
    message: aiCoachConsentText,
    confirmLabel: 'Turn on',
    destructive: false,
  );
  if (ok) await coach.setAiEnabled(true);
}
