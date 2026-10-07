import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/nutrition.dart';
import 'package:nutriq/domain/models/user_profile.dart';
import 'package:nutriq/services/coach/coach_backend.dart';
import 'package:nutriq/services/coach/coach_service.dart';
import 'package:nutriq/services/coach/demo_coach_service.dart';
import 'package:nutriq/state/coach_controller.dart';

import '../support/fake_coach_backend.dart';
import '../support/memory_local_store.dart';

CoachContext _ctx() => CoachContext(
  profile: const UserProfile(age: 30),
  today: NutritionTotals.zero,
  todayMealCount: 0,
  recentDays: const [],
  now: DateTime(2026, 10, 7, 12),
);

void main() {
  late MemoryLocalStore store;
  late FakeCoachBackend backend;

  CoachController controller({bool withAi = true}) => CoachController(
    DemoCoachService(replyDelay: Duration.zero),
    _ctx,
    ai: withAi ? backend : null,
    store: store,
  );

  setUp(() {
    store = MemoryLocalStore();
    backend = FakeCoachBackend();
  });

  test('without an account there is no AI choice and the demo coach answers', () async {
    final c = controller(withAi: false);
    await c.load();
    expect(c.aiAvailable, isFalse);
    expect(c.needsAiChoice, isFalse);
    expect(c.service.isDemo, isTrue);
  });

  test('with an account, the AI coach stays off until the person turns it on', () async {
    final c = controller();
    await c.load();
    expect(c.aiAvailable, isTrue);
    expect(c.needsAiChoice, isTrue);
    expect(c.service.isDemo, isTrue);

    await c.send('Protein?');
    expect(backend.payloads, isEmpty, reason: 'nothing is sent before opting in');
    expect(c.messages.last.isDemo, isTrue);

    await c.setAiEnabled(true);
    expect(c.needsAiChoice, isFalse);
    expect(c.aiEnabled, isTrue);
    expect(c.service.isDemo, isFalse);
    expect(await store.readMeta('coach_ai'), 'on');
  });

  test('the choice is remembered for this account on this phone', () async {
    await controller().setAiEnabled(false);
    final again = controller();
    await again.load();
    expect(again.needsAiChoice, isFalse);
    expect(again.aiEnabled, isFalse);
    expect(again.service.isDemo, isTrue);

    await again.setAiEnabled(true);
    final third = controller();
    await third.load();
    expect(third.aiEnabled, isTrue);
  });

  test('shows the reply as it streams, then adds it as an AI message', () async {
    final c = controller();
    await c.setAiEnabled(true);
    backend
      ..events = const [CoachDelta('Have '), CoachDelta('some eggs.'), CoachDone()]
      ..gate = Completer<void>();
    final seen = <String?>[];
    c.addListener(() => seen.add(c.streamingText));

    final sending = c.send('Breakfast idea?');
    await pumpEventQueue();
    expect(c.isReplying, isTrue);
    expect(c.streamingText, isNull);

    backend.gate!.complete();
    await sending;
    expect(seen, containsAllInOrder(['Have', 'Have some eggs.']));
    expect(c.streamingText, isNull);
    expect(c.isReplying, isFalse);
    final reply = c.messages.last;
    expect(reply.role, ChatRole.coach);
    expect(reply.text, 'Have some eggs.');
    expect(reply.isDemo, isFalse);
    expect(reply.notice, isNull);
  });

  test('a fallback reply keeps its notice', () async {
    final c = controller();
    await c.setAiEnabled(true);
    backend.error = const CoachBackendException(CoachFailure.offline);
    await c.send('Protein?');
    expect(c.messages.last.isDemo, isTrue);
    expect(c.messages.last.notice, contains('offline'));
  });

  test('clearing the chat while a reply is on its way drops that reply', () async {
    final c = controller();
    await c.setAiEnabled(true);
    backend.gate = Completer<void>();
    final sending = c.send('Hi');
    await pumpEventQueue();
    c.clear();
    backend.gate!.complete();
    await sending;
    expect(c.messages, isEmpty);
    expect(c.isReplying, isFalse);
  });

  test('closing the session mid-reply is safe', () async {
    final c = controller();
    await c.setAiEnabled(true);
    backend.gate = Completer<void>();
    final sending = c.send('Hi');
    await pumpEventQueue();
    c.dispose();
    backend.gate!.complete();
    await sending;
  });
}
