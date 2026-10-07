import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/nutrition.dart';
import 'package:nutriq/domain/models/user_profile.dart';
import 'package:nutriq/services/coach/ai_coach_service.dart';
import 'package:nutriq/services/coach/coach_backend.dart';
import 'package:nutriq/services/coach/coach_service.dart';
import 'package:nutriq/services/coach/demo_coach_service.dart';

import '../support/fake_coach_backend.dart';

CoachContext _ctx({UserProfile? profile = const UserProfile(age: 30, goal: FitnessGoal.maintain)}) => CoachContext(
  profile: profile,
  today: const NutritionTotals(calories: 900, protein: 50, carbs: 100, fat: 30),
  todayMealCount: 2,
  recentDays: const [],
  now: DateTime(2026, 10, 7, 12),
);

void main() {
  late FakeCoachBackend backend;
  late AiCoachService coach;

  setUp(() {
    backend = FakeCoachBackend();
    coach = AiCoachService(
      backend: backend,
      fallback: DemoCoachService(replyDelay: Duration.zero),
    );
  });

  test('is labelled as the AI coach, not a demo', () {
    expect(coach.isDemo, isFalse);
    expect(coach.label, 'AI coach');
  });

  test('streams partial text, then returns the full answer', () async {
    backend.events = const [CoachDelta('Aim for '), CoachDelta('30 g protein '), CoachDelta('at dinner.'), CoachDone()];
    final partials = <String>[];
    final reply = await coach.reply(message: 'Protein?', context: _ctx(), onPartial: partials.add);
    expect(partials, ['Aim for', 'Aim for 30 g protein', 'Aim for 30 g protein at dinner.']);
    expect(reply.text, 'Aim for 30 g protein at dinner.');
    expect(reply.kind, CoachReplyKind.answer);
    expect(reply.isDemo, isFalse);
    expect(reply.notice, isNull);
  });

  test('sends the question, history and context to the backend', () async {
    await coach.reply(
      message: 'Dinner idea?',
      context: _ctx(),
      history: const [ChatMessage(role: ChatRole.user, text: 'Dinner idea?')],
    );
    final payload = backend.payloads.single;
    expect(payload['messages'], [
      {'role': 'user', 'content': 'Dinner idea?'},
    ]);
    expect((payload['context'] as Map)['todayTotals'], isNotNull);
  });

  test('tidies markdown into plain text', () async {
    backend.events = const [CoachDelta('## Tips\n**Eat** more:\n- beans\n* eggs\n\n\n\nDone'), CoachDone()];
    final reply = await coach.reply(message: 'tips', context: _ctx());
    expect(reply.text, 'Tips\nEat more:\n• beans\n• eggs\n\nDone');
  });

  test('safety cues are answered on the phone and never sent', () async {
    final reply = await coach.reply(message: 'how do I make myself throw up', context: _ctx());
    expect(reply.kind, CoachReplyKind.safety);
    expect(reply.isDemo, isFalse);
    expect(backend.payloads, isEmpty);
  });

  test('under-18 weight-loss questions are refused on the phone', () async {
    final reply = await coach.reply(
      message: 'how do I lose weight',
      context: _ctx(profile: const UserProfile(age: 15)),
    );
    expect(reply.kind, CoachReplyKind.safety);
    expect(backend.payloads, isEmpty);
  });

  test('a server safety reply keeps its kind', () async {
    backend.events = const [CoachDelta('Please talk to a doctor.'), CoachDone(kind: CoachReplyKind.medical)];
    final reply = await coach.reply(message: 'something', context: _ctx());
    expect(reply.kind, CoachReplyKind.medical);
  });

  group('falls back to the labelled demo coach', () {
    Future<CoachReply> failWith(CoachBackendException e) {
      backend.error = e;
      return coach.reply(message: 'How am I doing with my protein today?', context: _ctx());
    }

    test('offline', () async {
      final r = await failWith(const CoachBackendException(CoachFailure.offline));
      expect(r.isDemo, isTrue);
      expect(r.text, contains('50'));
      expect(r.notice, 'You’re offline, so this is a scripted reply.');
    });

    test('signed out', () async {
      final r = await failWith(const CoachBackendException(CoachFailure.signedOut));
      expect(r.isDemo, isTrue);
      expect(r.notice, contains('Sign in again'));
    });

    test('not set up on the server', () async {
      final r = await failWith(const CoachBackendException(CoachFailure.notSetUp));
      expect(r.notice, contains('isn’t set up'));
    });

    test('daily limit, with the reset time', () async {
      final r = await failWith(
        CoachBackendException(CoachFailure.dailyLimit, limit: 30, resetsAt: DateTime.utc(2026, 10, 8)),
      );
      expect(r.isDemo, isTrue);
      expect(r.notice, startsWith('You’ve used today’s 30 AI messages — more from '));
      expect(r.notice, endsWith('. This is a scripted reply.'));
    });

    test('busy', () async {
      final r = await failWith(const CoachBackendException(CoachFailure.busy));
      expect(r.notice, contains('couldn’t answer just now'));
    });

    test('an empty reply counts as busy', () async {
      backend.events = const [];
      final r = await coach.reply(message: 'hi', context: _ctx());
      expect(r.isDemo, isTrue);
      expect(r.notice, contains('couldn’t answer just now'));
    });
  });

  test('a reply cut off part-way keeps what arrived and says so', () async {
    backend
      ..events = const [CoachDelta('Try a lentil '), CoachDelta('soup with'), CoachDone()]
      ..error = const CoachBackendException(CoachFailure.offline)
      ..errorAfter = 2;
    final r = await coach.reply(message: 'dinner?', context: _ctx());
    expect(r.text, 'Try a lentil soup with');
    expect(r.isDemo, isFalse);
    expect(r.notice, 'The connection dropped, so this reply may be cut off.');
  });

  test('a stream that ends without finishing counts as cut off', () async {
    backend.events = const [CoachDelta('Half an answer')];
    final r = await coach.reply(message: 'dinner?', context: _ctx());
    expect(r.text, 'Half an answer');
    expect(r.notice, contains('cut off'));
  });

  test('Today’s insight comes from the on-device rules', () {
    final c = _ctx();
    expect(coach.insight(c).text, DemoCoachService().insight(c).text);
  });
}
