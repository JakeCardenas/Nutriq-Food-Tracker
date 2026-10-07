import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/coach/coach_backend.dart';
import '../services/coach/coach_service.dart';

/// [CoachBackend] that calls the `coach` Edge Function with the signed-in
/// person's session. The AI key lives only in that function's secrets.
class SupabaseCoachBackend implements CoachBackend {
  SupabaseCoachBackend(this._client);

  final SupabaseClient _client;

  /// How long to wait for the reply to start, and between pieces of it.
  static const timeout = Duration(seconds: 40);

  @override
  Stream<CoachEvent> ask(Map<String, Object?> payload) async* {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke('coach', body: payload).timeout(timeout);
    } on FunctionException catch (e) {
      throw errorFor(e.status, e.details);
    } on TimeoutException {
      throw const CoachBackendException(CoachFailure.offline);
    } catch (_) {
      throw const CoachBackendException(CoachFailure.offline);
    }
    final data = response.data;
    if (data is! Stream<List<int>>) throw const CoachBackendException(CoachFailure.busy);
    try {
      yield* decode(data).timeout(timeout);
    } on CoachBackendException {
      rethrow;
    } catch (_) {
      // The connection dropped or stalled part-way through.
      throw const CoachBackendException(CoachFailure.offline);
    }
  }

  /// Reads the function's `data: {...}` server-sent events.
  static Stream<CoachEvent> decode(Stream<List<int>> bytes) async* {
    await for (final line in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final Object? event;
      try {
        event = jsonDecode(line.substring(5).trim());
      } on FormatException {
        continue;
      }
      if (event is! Map) continue;
      switch (event['t']) {
        case 'delta':
          final text = event['text'];
          if (text is String && text.isNotEmpty) yield CoachDelta(text);
        case 'done':
          yield CoachDone(
            kind: CoachReplyKind.values.asNameMap()[event['kind']] ?? CoachReplyKind.answer,
            remaining: (event['remaining'] as num?)?.toInt(),
          );
          return;
        case 'error':
          throw const CoachBackendException(CoachFailure.busy);
      }
    }
  }

  /// What a failed call means for the person. Status 0 = no response at all.
  static CoachBackendException errorFor(int status, Object? details) {
    final body = details is Map ? details : null;
    return switch (status) {
      0 => const CoachBackendException(CoachFailure.offline),
      401 || 403 => const CoachBackendException(CoachFailure.signedOut),
      404 || 503 => const CoachBackendException(CoachFailure.notSetUp),
      429 => CoachBackendException(
        CoachFailure.dailyLimit,
        limit: (body?['limit'] as num?)?.toInt(),
        resetsAt: body?['resetsAt'] is String ? DateTime.tryParse(body!['resetsAt'] as String) : null,
      ),
      _ => const CoachBackendException(CoachFailure.busy),
    };
  }
}
