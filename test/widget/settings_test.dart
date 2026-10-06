import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/user_profile.dart';
import 'package:nutriq/services/auth/auth_service.dart';
import 'package:nutriq/services/health/health_service.dart';

import '../support/fake_auth.dart';
import '../support/fake_cloud.dart';
import '../support/fake_health.dart';
import '../support/test_app.dart';

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.text('Settings').last);
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

const _alice = AuthUser(id: 'alice', email: 'alice@example.com', providers: ['email']);

void main() {
  testWidgets('without cloud config, Settings says data stays on this phone', (tester) async {
    final deps = await TestDeps.create();
    await deps.pumpApp(tester);
    await _openSettings(tester);
    expect(find.text('On this phone only'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('Apple Health is off until connected; reading and writing are separate', (tester) async {
    final health = FakeHealthService()..snapshot = const HealthSnapshot(steps: 6200, activeEnergyKcal: 310);
    final deps = await TestDeps.create(health: health);
    await deps.pumpApp(tester);
    expect(health.readRequests, 0, reason: 'no permission prompt at launch');
    expect(find.text('Activity · Apple Health'), findsNothing);

    await _openSettings(tester);
    await _tapText(tester, 'Connect Apple Health');
    expect(health.readRequests, 1);
    expect(health.writeRequests, 0, reason: 'writing is a separate opt-in');
    expect(find.text('Add meals to Apple Health'), findsOneWidget);

    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    expect(find.text('Activity · Apple Health'), findsOneWidget);
    expect(find.text('6,200'), findsOneWidget);
  });

  testWidgets('empty Apple Health data is described without claiming access was denied', (tester) async {
    final health = FakeHealthService();
    final deps = await TestDeps.create(health: health);
    await deps.pumpApp(tester);
    await _openSettings(tester);
    await _tapText(tester, 'Connect Apple Health');
    expect(find.textContaining('No Apple Health data found'), findsOneWidget);
    expect(find.textContaining('denied'), findsNothing);
    await _tapText(tester, 'Disconnect');
    await tester.tap(find.text('Disconnect').last);
    await tester.pumpAndSettle();
    expect(deps.health.isConnected, isFalse);
    await tester.scrollUntilVisible(find.text('Connect Apple Health'), -200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Connect Apple Health'), findsOneWidget);
  });

  testWidgets('Apple Health is reported as unavailable where it isn’t supported', (tester) async {
    final deps = await TestDeps.create(health: const UnsupportedHealthService());
    await deps.pumpApp(tester);
    await _openSettings(tester);
    await tester.scrollUntilVisible(find.text('Not available'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Not available'), findsOneWidget);
  });

  testWidgets('changing age to under 18 removes calorie and protein targets', (tester) async {
    final deps = await TestDeps.create(
      profile: const UserProfile(age: 30, calorieGoal: CalorieRange(min: 1900, max: 2200), proteinTargetG: 120),
    );
    await deps.pumpApp(tester);
    await _openSettings(tester);
    await _tapText(tester, 'Personal details');
    await _tapText(tester, 'Age');
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, 14 * 42.0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(deps.profile.profile!.age, 16);
    expect(deps.profile.profile!.calorieGoal, isNull);
    expect(deps.profile.profile!.proteinTargetG, isNull);
    expect(find.textContaining('under 18'), findsOneWidget);
  });

  group('signed in', () {
    late FakeAuthService auth;
    late FakeCloud cloud;
    late TestDeps deps;

    Future<void> signIn(WidgetTester tester) async {
      auth = FakeAuthService();
      cloud = FakeCloud();
      deps = await TestDeps.create(auth: auth, cloud: cloud);
      auth.signIn(_alice);
      // Let the session switch to the account (fake-async: advance time instead of awaiting).
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(deps.session.isAccount, isTrue);
      await deps.pumpApp(tester);
      await _openSettings(tester);
    }

    testWidgets('shows the account, sync status and account deletion', (tester) async {
      await signIn(tester);
      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Delete account'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Delete synced data'), findsOneWidget);
      expect(find.text('Remove account from this phone'), findsOneWidget);
    });

    testWidgets('if account deletion isn’t deployed, it says nothing was deleted', (tester) async {
      await signIn(tester);
      cloud.accountFunctionMissing = true;
      await _tapText(tester, 'Delete account');
      await tester.tap(find.text('Delete account').last);
      await tester.pumpAndSettle();
      expect(find.text('Nothing was deleted'), findsOneWidget);
      expect(find.textContaining('hasn’t been deployed'), findsOneWidget);
      expect(deps.session.isAccount, isTrue);
      expect(auth.currentUser, isNotNull);
    });

    testWidgets('deleting the account signs out to this phone’s local data', (tester) async {
      await signIn(tester);
      await _tapText(tester, 'Delete account');
      await tester.tap(find.text('Delete account').last);
      await tester.pumpAndSettle();
      expect(cloud.deletedAccount, isTrue);
      expect(deps.session.isAccount, isFalse);
      expect(auth.currentUser, isNull);
    });
  });
}
