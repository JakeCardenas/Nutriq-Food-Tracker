import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/services/health/health_service.dart';

import '../support/fake_health.dart';
import '../support/test_app.dart';

Future<void> _swipeToActivity(WidgetTester tester) async {
  await tester.drag(find.byKey(const ValueKey('nutrition-pager')), const Offset(-400, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('macros and activity share a pager with page dots', (tester) async {
    final health = FakeHealthService()..snapshot = const HealthSnapshot(steps: 8421, activeEnergyKcal: 412);
    final deps = await TestDeps.create(health: health);
    await deps.health.connect();
    await deps.pumpApp(tester);

    expect(find.byKey(const ValueKey('page-dots')), findsOneWidget);
    expect(find.text('Protein eaten'), findsOneWidget);
    await _swipeToActivity(tester);
    expect(find.text('8,421'), findsOneWidget);
    expect(find.text('Steps today'), findsOneWidget);
  });

  testWidgets('with Apple Health off, the activity page points to Settings and asks for nothing', (tester) async {
    final health = FakeHealthService();
    final deps = await TestDeps.create(health: health);
    await deps.pumpApp(tester);

    await _swipeToActivity(tester);
    expect(find.text('See your activity here'), findsOneWidget);
    expect(health.readRequests, 0);

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Connect Apple Health'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Connect Apple Health'), findsOneWidget);
    expect(health.readRequests, 0, reason: 'permission is only requested from Settings');
  });

  testWidgets('where Apple Health isn’t available there is no second page', (tester) async {
    final deps = await TestDeps.create(health: const UnsupportedHealthService());
    await deps.pumpApp(tester);
    expect(find.byKey(const ValueKey('page-dots')), findsNothing);
    expect(find.text('Protein eaten'), findsOneWidget);
  });
}
