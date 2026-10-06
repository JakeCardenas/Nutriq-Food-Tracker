import 'sync_models.dart';

/// The signed-in account's data in the cloud (Supabase). Every call acts only
/// on the caller's own rows — enforced server-side by Row Level Security.
abstract interface class CloudRepository {
  /// Upserts one record. Refuses (returns [PushResult.stale]) when the server
  /// already holds a newer edit, and returns that newer version.
  Future<PushResult> push(SyncRecord record);

  /// Server changes after [cursor] (null = everything), oldest first.
  Future<PullPage> pull(SyncEntity entity, String? cursor);

  /// Deletes every row this user owns (profile, meals, items, foods, feedback).
  Future<void> deleteAllMyData();

  /// Deletes the auth account via the server-side `delete-account` function.
  Future<void> deleteAccount();
}

class PushResult {
  const PushResult.ok() : stale = false, current = null;
  const PushResult.stale(this.current) : stale = true;

  final bool stale;

  /// The server's newer version (or a deletion) when [stale].
  final SyncRecord? current;
}

class PullPage {
  const PullPage({required this.records, required this.cursor, required this.hasMore});
  final List<SyncRecord> records;
  final String? cursor;
  final bool hasMore;
}

/// No connection / server unreachable. Changes stay pending.
class CloudOfflineException implements Exception {
  const CloudOfflineException([this.message = 'No connection']);
  final String message;
  @override
  String toString() => message;
}

/// The server refused a record (for example a value out of range).
class CloudRejectedException implements Exception {
  const CloudRejectedException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The session expired or the user isn't signed in.
class CloudAuthException implements Exception {
  const CloudAuthException([this.message = 'Please sign in again']);
  final String message;
  @override
  String toString() => message;
}

/// A server feature that hasn't been deployed (e.g. the delete-account function).
class CloudNotConfiguredException implements Exception {
  const CloudNotConfiguredException(this.message);
  final String message;
  @override
  String toString() => message;
}
