import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/app/theme.dart';
import 'package:nutriq/widgets/sheet.dart';

/// Opens a sheet from a host page and records what it returns.
class _Host {
  Object? result = 'not closed';
  bool closed = false;

  Future<void> pump(WidgetTester tester, {bool reduceMotion = false, bool dismissible = true, Widget? body}) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: const Size(400, 800), disableAnimations: reduceMotion),
        child: MaterialApp(
          theme: buildNutriqTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await showNqSheet<String>(
                      context,
                      title: 'Test sheet',
                      dismissible: dismissible,
                      child:
                          body ??
                          Builder(
                            builder: (sheetContext) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 160, child: Text('Sheet content')),
                                TextButton(
                                  onPressed: () => Navigator.pop(sheetContext, 'done'),
                                  child: const Text('Done'),
                                ),
                              ],
                            ),
                          ),
                    );
                    closed = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

double _sheetTop(WidgetTester tester) => tester.getTopLeft(find.text('Test sheet')).dy;

void main() {
  testWidgets('the sheet follows the finger 1:1 while dragging', (tester) async {
    final host = _Host();
    await host.pump(tester);
    final restingTop = _sheetTop(tester);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Sheet content')));
    await gesture.moveBy(const Offset(0, 20)); // past the drag slop
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    expect(_sheetTop(tester) - restingTop, moreOrLessEquals(120, epsilon: 20));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a short, slow drag settles back open', (tester) async {
    final host = _Host();
    await host.pump(tester);
    final restingTop = _sheetTop(tester);

    await tester.timedDrag(find.text('Sheet content'), const Offset(0, 60), const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(host.closed, isFalse);
    expect(_sheetTop(tester), moreOrLessEquals(restingTop, epsilon: 0.5));
  });

  testWidgets('dragging most of the way down dismisses it', (tester) async {
    final host = _Host();
    await host.pump(tester);

    await tester.timedDrag(find.text('Sheet content'), const Offset(0, 260), const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(host.closed, isTrue);
    expect(host.result, isNull);
    expect(find.text('Test sheet'), findsNothing);
  });

  testWidgets('a quick flick dismisses even from a short distance', (tester) async {
    final host = _Host();
    await host.pump(tester);

    await tester.fling(find.text('Sheet content'), const Offset(0, 80), 1500);
    await tester.pumpAndSettle();
    expect(host.closed, isTrue);
  });

  testWidgets('an upward drag past the top resists and springs back', (tester) async {
    final host = _Host();
    await host.pump(tester);
    final restingTop = _sheetTop(tester);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Sheet content')));
    await gesture.moveBy(const Offset(0, -20));
    await gesture.moveBy(const Offset(0, -200));
    await tester.pump();
    final lifted = restingTop - _sheetTop(tester);
    expect(lifted, greaterThan(0));
    expect(lifted, lessThan(110), reason: 'rubber-banded, not 1:1');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_sheetTop(tester), moreOrLessEquals(restingTop, epsilon: 0.5));
  });

  testWidgets('tapping outside closes it, and buttons inside return values', (tester) async {
    final host = _Host();
    await host.pump(tester);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(host.closed, isTrue);

    final second = _Host();
    await second.pump(tester);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(second.result, 'done');
  });

  testWidgets('a sheet that must be answered cannot be swiped or tapped away', (tester) async {
    final host = _Host();
    await host.pump(tester, dismissible: false);
    await tester.fling(find.text('Sheet content'), const Offset(0, 300), 2000);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(host.closed, isFalse);
    expect(find.text('Test sheet'), findsOneWidget);
  });

  testWidgets('pulling down on scrolled-to-top content drags the sheet', (tester) async {
    final host = _Host();
    await host.pump(
      tester,
      body: Column(children: [for (var i = 0; i < 40; i++) SizedBox(height: 48, child: Text('Row $i'))]),
    );
    await tester.timedDrag(find.text('Row 3'), const Offset(0, 500), const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(host.closed, isTrue);
  });

  testWidgets('content that can scroll still scrolls up normally', (tester) async {
    final host = _Host();
    await host.pump(
      tester,
      body: Column(children: [for (var i = 0; i < 40; i++) SizedBox(height: 48, child: Text('Row $i'))]),
    );
    final before = tester.getTopLeft(find.text('Row 3')).dy;
    await tester.timedDrag(find.text('Row 3'), const Offset(0, -200), const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Row 3')).dy, lessThan(before - 100));
    expect(host.closed, isFalse);
  });

  testWidgets('with Reduce Motion the sheet appears in place instead of sliding up', (tester) async {
    final host = _Host();
    await host.pump(tester, reduceMotion: true);
    final finalTop = _sheetTop(tester);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(host.result, 'done');

    // Re-open and look at the first frames: the sheet is already where it rests.
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_sheetTop(tester), moreOrLessEquals(finalTop, epsilon: 0.5));
    await tester.pumpAndSettle();
  });
}
