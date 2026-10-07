import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/app/theme.dart';
import 'package:nutriq/domain/models/nutrition.dart';
import 'package:nutriq/features/history/week_chart.dart';
import 'package:nutriq/services/coach/coach_service.dart' show DaySummary;
import 'package:nutriq/widgets/week_strip.dart';

void main() {
  testWidgets('each day in the History chart is a labelled, selectable button for VoiceOver', (tester) async {
    DateTime? tapped;
    final mon = DateTime(2026, 10, 5);
    final tue = DateTime(2026, 10, 6);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildNutriqTheme(),
        home: Scaffold(
          body: WeekChart(
            days: [
              DaySummary(day: mon, totals: NutritionTotals.zero, mealCount: 0),
              DaySummary(day: tue, totals: const NutritionTotals(calories: 300), mealCount: 1),
            ],
            range: null,
            selected: tue,
            onSelect: (d) => tapped = d,
          ),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    final tuesday = find.bySemanticsLabel('Tuesday, October 6, about 300 calories');
    final monday = find.bySemanticsLabel('Monday, October 5, nothing logged');
    expect(tuesday, findsOneWidget);
    expect(monday, findsOneWidget);
    final data = tester.getSemantics(tuesday).getSemanticsData();
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(tester.getSemantics(monday).getSemanticsData().flagsCollection.isSelected, Tristate.isFalse);
    semantics.dispose();

    await tester.tap(find.text('5'));
    expect(tapped, mon);
  });

  testWidgets('Today’s week strip: VoiceOver can select a past day; future days aren’t buttons', (tester) async {
    DateTime? tapped;
    final mon = DateTime(2026, 10, 5);
    final tue = DateTime(2026, 10, 6);
    final wed = DateTime(2026, 10, 7);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildNutriqTheme(),
        home: Scaffold(
          body: WeekStrip(
            days: [
              for (final d in [mon, tue, wed]) DaySummary(day: d, totals: NutritionTotals.zero, mealCount: 0),
            ],
            selected: tue,
            today: tue,
            range: null,
            onSelect: (d) => tapped = d,
          ),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    final monday = tester.getSemantics(find.bySemanticsLabel('Monday, October 5, nothing logged'));
    expect(monday.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    final future = tester.getSemantics(find.bySemanticsLabel('Wednesday, October 7, nothing logged'));
    expect(future.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    tester.semantics.tap(find.semantics.byLabel('Monday, October 5, nothing logged'));
    semantics.dispose();
    expect(tapped, mon, reason: 'the VoiceOver activation selects the day');
  });
}
