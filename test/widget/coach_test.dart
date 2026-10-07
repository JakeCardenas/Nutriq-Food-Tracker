import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/services/auth/auth_service.dart';
import 'package:nutriq/services/coach/coach_backend.dart';
import 'package:nutriq/widgets/surfaces.dart';

import '../support/fake_auth.dart';
import '../support/fake_cloud.dart';
import '../support/fake_coach_backend.dart';
import '../support/test_app.dart';

const _alice = AuthUser(id: 'alice', email: 'alice@example.com', providers: ['email']);

Future<void> _openTab(WidgetTester tester, String tab) async {
  await tester.tap(find.text(tab).last);
  await tester.pumpAndSettle();
}

Future<void> _ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(); // let the send button enable
  await tester.tap(find.byTooltip('Send'));
}

void main() {
  late FakeCoachBackend backend;
  late TestDeps deps;

  setUp(() => backend = FakeCoachBackend());

  Future<void> signedIn(WidgetTester tester) async {
    final auth = FakeAuthService();
    deps = await TestDeps.create(auth: auth, cloud: FakeCloud(), coachBackend: backend);
    auth.signIn(_alice);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(deps.session.isAccount, isTrue);
    await deps.pumpApp(tester);
    await _openTab(tester, 'Coach');
  }

  testWidgets('signed out: scripted coach, with a pointer to the AI coach', (tester) async {
    deps = await TestDeps.create(auth: FakeAuthService(), coachBackend: backend);
    await deps.pumpApp(tester);
    await _openTab(tester, 'Coach');
    expect(find.text('Demo coach'), findsOneWidget);
    expect(find.text('Try the AI coach?'), findsNothing);
    expect(find.textContaining('Sign in to try the AI coach'), findsOneWidget);

    await _ask(tester, 'How am I doing with my protein today?');
    await tester.pumpAndSettle();
    expect(find.text('Demo coach · scripted'), findsOneWidget);
    expect(backend.payloads, isEmpty);
  });

  testWidgets('signed in: asks before using the AI, and explains what is sent', (tester) async {
    await signedIn(tester);
    expect(find.text('Try the AI coach?'), findsOneWidget);
    expect(find.textContaining('Anthropic'), findsWidgets);
    expect(find.textContaining('Meal photos and Apple Health data are never sent'), findsOneWidget);
    expect(find.text('Demo coach'), findsOneWidget);

    await tester.tap(find.text('Turn on AI coach'));
    await tester.pumpAndSettle();
    expect(find.text('Try the AI coach?'), findsNothing);
    expect(find.text('Demo coach'), findsNothing);
    expect(find.text('AI coach'), findsOneWidget);
    expect(deps.coach.aiEnabled, isTrue);

    await _ask(tester, 'Suggest a dinner');
    await tester.pumpAndSettle();
    expect(find.text('AI says hi.'), findsOneWidget);
    expect(find.text('AI coach · can make mistakes'), findsOneWidget);
    expect(backend.payloads, hasLength(1));
  });

  testWidgets('signed in: “Not now” keeps the scripted coach and sends nothing', (tester) async {
    await signedIn(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Try the AI coach?'), findsNothing);
    expect(find.textContaining('Turn on the AI coach in Settings'), findsOneWidget);

    await _ask(tester, 'How am I doing with my protein today?');
    await tester.pumpAndSettle();
    expect(find.text('Demo coach · scripted'), findsOneWidget);
    expect(backend.payloads, isEmpty);
  });

  testWidgets('the reply appears while it streams in', (tester) async {
    await signedIn(tester);
    await tester.tap(find.text('Turn on AI coach'));
    await tester.pumpAndSettle();
    backend
      ..events = const [CoachDelta('Lentils are '), CoachDelta('a great pick.'), CoachDone()]
      ..gate = Completer<void>();

    await _ask(tester, 'Dinner?');
    await tester.pump();
    expect(find.bySemanticsLabel('Coach is replying'), findsOneWidget);

    backend.gate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Lentils are'), findsOneWidget);
    expect(find.text('AI coach · can make mistakes'), findsNothing, reason: 'not labelled until complete');

    await tester.pumpAndSettle();
    expect(find.text('Lentils are a great pick.'), findsOneWidget);
    expect(find.text('AI coach · can make mistakes'), findsOneWidget);
  });

  testWidgets('when the AI can’t answer, the scripted reply says why', (tester) async {
    await signedIn(tester);
    await tester.tap(find.text('Turn on AI coach'));
    await tester.pumpAndSettle();
    backend.error = const CoachBackendException(CoachFailure.offline);

    await _ask(tester, 'How am I doing with my protein today?');
    await tester.pumpAndSettle();
    expect(find.text('You’re offline, so this is a scripted reply.'), findsOneWidget);
  });

  testWidgets('Settings: the AI coach switch asks before turning on', (tester) async {
    await signedIn(tester);
    await _openTab(tester, 'Settings');
    final scrollable = find.byType(Scrollable).first;
    final toggle = find.descendant(
      of: find.ancestor(of: find.text('AI coach'), matching: find.byType(NqRow)),
      matching: find.byWidgetPredicate((w) => w is Switch || w is CupertinoSwitch),
    );
    await tester.scrollUntilVisible(find.text('AI coach'), 200, scrollable: scrollable);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Turn on the AI coach?'), findsOneWidget);
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(deps.coach.aiEnabled, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Turn on the AI coach?'), findsNothing, reason: 'turning off needs no confirmation');
    expect(deps.coach.aiEnabled, isFalse);
  });

  testWidgets('Settings: About shows which coach is answering', (tester) async {
    await signedIn(tester);
    await deps.coach.setAiEnabled(true);
    await _openTab(tester, 'Settings');
    await tester.scrollUntilVisible(find.text('AI · Claude'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('AI · Claude'), findsOneWidget);
  });

  testWidgets('Settings: no AI coach switch without an account', (tester) async {
    deps = await TestDeps.create(auth: FakeAuthService(), coachBackend: backend);
    await deps.pumpApp(tester);
    await _openTab(tester, 'Settings');
    expect(find.text('AI coach'), findsNothing);
  });
}
