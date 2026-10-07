import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/data/supabase_coach_backend.dart';
import 'package:nutriq/services/coach/coach_backend.dart';
import 'package:nutriq/services/coach/coach_service.dart';

/// Splits [text] into tiny byte chunks, so lines and multi-byte characters
/// arrive in pieces like they do over a real connection.
Stream<List<int>> _chunks(String text, {int size = 3}) async* {
  final bytes = utf8.encode(text);
  for (var i = 0; i < bytes.length; i += size) {
    yield bytes.sublist(i, i + size > bytes.length ? bytes.length : i + size);
  }
}

String _event(Map<String, Object?> e) => 'data: ${jsonEncode(e)}\n\n';

void main() {
  group('event stream', () {
    test('decodes deltas and done across chunk boundaries', () async {
      final events = await SupabaseCoachBackend.decode(
        _chunks(
          ': keep-alive\n\n'
          '${_event({'t': 'delta', 'text': 'Café '})}'
          '${_event({'t': 'delta', 'text': 'au lait — 🥛'})}'
          'data: not json\n\n'
          '${_event({'t': 'done', 'kind': 'answer', 'remaining': 7})}',
        ),
      ).toList();
      expect(events, hasLength(3));
      expect((events[0] as CoachDelta).text, 'Café ');
      expect((events[1] as CoachDelta).text, 'au lait — 🥛');
      final done = events[2] as CoachDone;
      expect(done.kind, CoachReplyKind.answer);
      expect(done.remaining, 7);
    });

    test('maps the server’s reply kinds', () async {
      final events = await SupabaseCoachBackend.decode(
        _chunks(_event({'t': 'delta', 'text': 'x'}) + _event({'t': 'done', 'kind': 'medical'})),
      ).toList();
      expect((events.last as CoachDone).kind, CoachReplyKind.medical);
    });

    test('an error event becomes a busy failure', () async {
      final stream = SupabaseCoachBackend.decode(
        _chunks(_event({'t': 'delta', 'text': 'Par'}) + _event({'t': 'error', 'code': 'busy'})),
      );
      final seen = <CoachEvent>[];
      await expectLater(
        stream.forEach(seen.add),
        throwsA(isA<CoachBackendException>().having((e) => e.failure, 'failure', CoachFailure.busy)),
      );
      expect(seen, hasLength(1));
    });
  });

  group('HTTP errors', () {
    CoachFailure failure(int status, [Object? details]) => SupabaseCoachBackend.errorFor(status, details).failure;

    test('maps statuses to what the person is told', () {
      expect(failure(0), CoachFailure.offline);
      expect(failure(401), CoachFailure.signedOut);
      expect(failure(403), CoachFailure.signedOut);
      expect(failure(404), CoachFailure.notSetUp);
      expect(failure(503), CoachFailure.notSetUp);
      expect(failure(400), CoachFailure.busy);
      expect(failure(500), CoachFailure.busy);
      expect(failure(502), CoachFailure.busy);
    });

    test('a daily limit carries the limit and reset time', () {
      final e = SupabaseCoachBackend.errorFor(429, {
        'error': 'daily_limit',
        'limit': 30,
        'resetsAt': '2026-10-08T00:00:00.000Z',
      });
      expect(e.failure, CoachFailure.dailyLimit);
      expect(e.limit, 30);
      expect(e.resetsAt, DateTime.utc(2026, 10, 8));
    });

    test('a daily limit without details still works', () {
      final e = SupabaseCoachBackend.errorFor(429, 'Too many requests');
      expect(e.failure, CoachFailure.dailyLimit);
      expect(e.resetsAt, isNull);
    });
  });
}
