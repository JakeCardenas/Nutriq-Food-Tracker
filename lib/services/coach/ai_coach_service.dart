import 'package:intl/intl.dart';

import 'coach_backend.dart';
import 'coach_payload.dart';
import 'coach_safety.dart';
import 'coach_service.dart';

/// The real coach: Claude, reached through Nutriq's `coach` server function.
///
/// The same on-device safety rules run first (and again on the server). When
/// the AI can't answer — offline, signed out, not set up, or over today's
/// allowance — the scripted [fallback] answers instead, and the reply says so.
class AiCoachService implements CoachService {
  AiCoachService({required this.backend, required this.fallback});

  final CoachBackend backend;
  final CoachService fallback;

  @override
  bool get isDemo => false;

  @override
  String get label => 'AI coach';

  @override
  Future<CoachReply> reply({
    required String message,
    required CoachContext context,
    List<ChatMessage> history = const [],
    void Function(String textSoFar)? onPartial,
  }) async {
    final safety = CoachSafety.check(message, context, isDemo: false);
    if (safety != null) return safety;

    final payload = CoachPayload.build(message: message, context: context, history: history);
    final buffer = StringBuffer();
    CoachDone? done;
    CoachBackendException? failure;
    try {
      await for (final event in backend.ask(payload)) {
        switch (event) {
          case CoachDelta(:final text):
            buffer.write(text);
            onPartial?.call(tidyCoachText(buffer.toString()));
          case CoachDone():
            done = event;
        }
      }
    } on CoachBackendException catch (e) {
      failure = e;
    } catch (_) {
      failure = const CoachBackendException(CoachFailure.busy);
    }

    final text = tidyCoachText(buffer.toString());
    if (text.isNotEmpty) {
      return CoachReply(
        text: text,
        kind: done?.kind ?? CoachReplyKind.answer,
        isDemo: false,
        notice: done == null ? 'The connection dropped, so this reply may be cut off.' : null,
      );
    }
    final scripted = await fallback.reply(message: message, context: context, history: history);
    return CoachReply(
      text: scripted.text,
      kind: scripted.kind,
      isDemo: scripted.isDemo,
      notice: noticeFor(failure ?? const CoachBackendException(CoachFailure.busy)),
    );
  }

  @override
  CoachInsight insight(CoachContext context) => fallback.insight(context);

  /// What the person is told when the AI couldn't answer.
  static String noticeFor(CoachBackendException e) => switch (e.failure) {
    CoachFailure.offline => 'You’re offline, so this is a scripted reply.',
    CoachFailure.signedOut => 'Sign in again to use the AI coach. This is a scripted reply.',
    CoachFailure.notSetUp => 'The AI coach isn’t set up on the server yet, so this is a scripted reply.',
    CoachFailure.dailyLimit =>
      'You’ve used today’s ${e.limit == null ? 'AI' : '${e.limit} AI'} messages'
          '${e.resetsAt == null ? '' : ' — more from ${DateFormat.jm().format(e.resetsAt!.toLocal())}'}'
          '. This is a scripted reply.',
    CoachFailure.busy => 'The AI coach couldn’t answer just now, so this is a scripted reply.',
  };
}

/// Turns the little markdown a model may still use into plain chat text.
String tidyCoachText(String text) {
  final lines = text.replaceAll('**', '').replaceAll('__', '').split('\n').map((line) {
    final heading = RegExp(r'^\s{0,3}#{1,6}\s+').firstMatch(line);
    if (heading != null) return line.substring(heading.end);
    final bullet = RegExp(r'^(\s*)[-*]\s+').firstMatch(line);
    if (bullet != null) return '${bullet.group(1)}• ${line.substring(bullet.end)}';
    return line;
  });
  return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
