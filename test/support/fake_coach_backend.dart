import 'dart:async';

import 'package:nutriq/services/coach/coach_backend.dart';

/// Scripted stand-in for the `coach` Edge Function.
class FakeCoachBackend implements CoachBackend {
  FakeCoachBackend({this.events = const [CoachDelta('AI says hi.'), CoachDone()], this.error, this.errorAfter});

  /// What the next calls stream back.
  List<CoachEvent> events;

  /// Thrown instead of (or, with [errorAfter], part-way through) [events].
  CoachBackendException? error;
  int? errorAfter;

  /// When set, each call waits for this before streaming.
  Completer<void>? gate;

  final payloads = <Map<String, Object?>>[];

  @override
  Stream<CoachEvent> ask(Map<String, Object?> payload) async* {
    payloads.add(payload);
    if (gate != null) await gate!.future;
    final failure = error;
    if (failure != null && errorAfter == null) throw failure;
    for (var i = 0; i < events.length; i++) {
      if (failure != null && i == errorAfter) throw failure;
      yield events[i];
      await Future<void>.delayed(Duration.zero);
    }
  }
}
