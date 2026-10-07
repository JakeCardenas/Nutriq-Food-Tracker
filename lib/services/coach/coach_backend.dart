import 'coach_service.dart';

/// Transport to Nutriq's `coach` server function, which holds the AI key.
abstract interface class CoachBackend {
  /// Sends [payload] (see `CoachPayload`) and streams the reply.
  /// Fails with a [CoachBackendException].
  Stream<CoachEvent> ask(Map<String, Object?> payload);
}

sealed class CoachEvent {
  const CoachEvent();
}

/// The next piece of reply text.
class CoachDelta extends CoachEvent {
  const CoachDelta(this.text);
  final String text;
}

/// The reply is complete.
class CoachDone extends CoachEvent {
  const CoachDone({this.kind = CoachReplyKind.answer, this.remaining});
  final CoachReplyKind kind;

  /// AI messages left today, when the server says.
  final int? remaining;
}

enum CoachFailure { offline, signedOut, notSetUp, dailyLimit, busy }

class CoachBackendException implements Exception {
  const CoachBackendException(this.failure, {this.limit, this.resetsAt});
  final CoachFailure failure;

  /// For [CoachFailure.dailyLimit].
  final int? limit;
  final DateTime? resetsAt;

  @override
  String toString() => 'CoachBackendException($failure)';
}
