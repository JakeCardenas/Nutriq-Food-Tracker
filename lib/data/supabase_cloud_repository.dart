import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_mappers.dart';
import 'cloud_repository.dart';
import 'sync_models.dart';

/// [CloudRepository] backed by Supabase (PostgREST + RPC + Edge Functions).
/// Row Level Security on the server limits every call to the caller's rows.
class SupabaseCloudRepository implements CloudRepository {
  SupabaseCloudRepository(this._client);

  final SupabaseClient _client;
  static const _pageSize = 500;

  @override
  Future<PushResult> push(SyncRecord record) => _guard(() async {
    final (fn, params) = switch (record.entity) {
      SyncEntity.meal => ('nutriq_push_meal', CloudMappers.mealPushParams(record)),
      SyncEntity.profile => ('nutriq_push_profile', CloudMappers.profilePushParams(record)),
      SyncEntity.savedFood => ('nutriq_push_saved_food', CloudMappers.savedFoodPushParams(record)),
      SyncEntity.scanFeedback => ('nutriq_push_scan_feedback', CloudMappers.feedbackPushParams(record)),
    };
    final response = (await _client.rpc(fn, params: params) as Map).cast<String, Object?>();
    if (response['status'] != 'stale') return const PushResult.ok();
    final current = (response['current'] as Map?)?.cast<String, Object?>();
    return PushResult.stale(current == null ? null : _fromRow(record.entity, current));
  });

  @override
  Future<PullPage> pull(SyncEntity entity, String? cursor) => _guard(() async {
    final (table, columns) = switch (entity) {
      SyncEntity.profile => ('profiles', '*'),
      SyncEntity.meal => ('meals', '*, meal_items(*)'),
      SyncEntity.savedFood => ('saved_foods', '*'),
      SyncEntity.scanFeedback => ('scan_feedback', '*'),
    };
    // Keyset cursor "updated_at|id": fetch rows at or after the timestamp and
    // skip the ones already seen at that exact timestamp.
    final parts = cursor?.split('|');
    final since = parts?.first;
    final lastId = parts != null && parts.length > 1 ? parts[1] : null;
    final idColumn = entity == SyncEntity.profile ? 'user_id' : 'id';

    var query = _client.from(table).select(columns);
    if (since != null) query = query.gte('updated_at', since);
    final rows = (await query.order('updated_at').order(idColumn).limit(_pageSize))
        .map((r) => r.cast<String, Object?>())
        .toList();

    final fresh = rows.where((r) {
      if (since == null || r['updated_at'] != since) return true;
      return lastId == null || (r[idColumn] as String).compareTo(lastId) > 0;
    }).toList();
    final next = rows.isEmpty ? cursor : '${rows.last['updated_at']}|${rows.last[idColumn]}';
    return PullPage(
      records: [for (final r in fresh) _fromRow(entity, r)],
      cursor: next,
      hasMore: rows.length == _pageSize,
    );
  });

  @override
  Future<void> deleteAllMyData() => _guard(() => _client.rpc('nutriq_delete_my_data'));

  @override
  Future<void> deleteAccount() => _guard(() async {
    try {
      await _client.functions.invoke('delete-account', method: HttpMethod.post);
    } on FunctionException catch (e) {
      throw deleteAccountError(e.status);
    }
  });

  /// What a failed `delete-account` call means for the person. Status 0 means
  /// no response at all (the request never reached the server).
  static Exception deleteAccountError(int status) => switch (status) {
    0 => const CloudOfflineException(),
    401 || 403 => const CloudAuthException(),
    404 => const CloudNotConfiguredException(
      'Account deletion isn’t set up on the server yet (deploy the delete-account function).',
    ),
    _ => CloudRejectedException('Account deletion failed (error $status).'),
  };

  static SyncRecord _fromRow(SyncEntity entity, Map<String, Object?> row) => switch (entity) {
    SyncEntity.profile => CloudMappers.profileFromRow(row),
    SyncEntity.meal => CloudMappers.mealFromRow(row),
    SyncEntity.savedFood => CloudMappers.savedFoodFromRow(row),
    SyncEntity.scanFeedback => CloudMappers.feedbackFromRow(row),
  };

  /// Maps transport and server errors to the sync engine's vocabulary.
  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body().timeout(const Duration(seconds: 30));
    } on SocketException {
      throw const CloudOfflineException();
    } on TimeoutException {
      throw const CloudOfflineException('The server took too long to respond');
    } on AuthRetryableFetchException {
      throw const CloudOfflineException();
    } on AuthException {
      throw const CloudAuthException();
    } on PostgrestException catch (e) {
      final code = e.code ?? '';
      if (code == 'PGRST301' || code == '28000' || code == '42501') throw const CloudAuthException();
      // Data problems (check/format/not-null violations) — this record won't sync as-is.
      throw CloudRejectedException(e.message);
    } on CloudOfflineException {
      rethrow;
    } catch (e) {
      final text = '$e';
      if (text.contains('ClientException') || text.contains('Failed host lookup') || text.contains('Connection')) {
        throw const CloudOfflineException();
      }
      rethrow;
    }
  }
}
