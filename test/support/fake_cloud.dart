import 'package:nutriq/data/cloud_repository.dart';
import 'package:nutriq/data/sync_models.dart';

class ServerRow {
  ServerRow(this.json, this.clientUpdatedAt, this.seq, {this.deleted = false});
  Map<String, Object?>? json;
  int clientUpdatedAt;
  int seq;
  bool deleted;
}

/// In-memory stand-in for the Supabase backend with the same rules as the
/// SQL push functions: stale writes (older client timestamp) are refused and
/// the current row is returned; deletes are soft so other devices learn them.
class FakeCloud implements CloudRepository {
  final Map<SyncEntity, Map<String, ServerRow>> rows = {for (final e in SyncEntity.values) e: {}};
  int _seq = 0;
  bool offline = false;
  final Set<String> rejectIds = {};
  int pushCalls = 0;
  bool deletedAccount = false;

  /// Simulates a project where the `delete-account` Edge Function isn't deployed.
  bool accountFunctionMissing = false;

  /// Simulates another device writing directly to the server.
  void serverWrite(SyncEntity e, String id, Map<String, Object?>? json, int clientUpdatedAt, {bool deleted = false}) {
    rows[e]![id] = ServerRow(json, clientUpdatedAt, ++_seq, deleted: deleted);
  }

  int count(SyncEntity e) => rows[e]!.values.where((r) => !r.deleted).length;

  @override
  Future<PushResult> push(SyncRecord record) async {
    if (offline) throw const CloudOfflineException();
    pushCalls++;
    if (rejectIds.contains(record.id)) throw const CloudRejectedException('Value out of range');
    final existing = rows[record.entity]![record.id];
    if (existing != null && existing.clientUpdatedAt > record.updatedAt) {
      return PushResult.stale(
        SyncRecord(
          entity: record.entity,
          id: record.id,
          updatedAt: existing.clientUpdatedAt,
          json: existing.deleted ? null : existing.json,
          deleted: existing.deleted,
        ),
      );
    }
    serverWrite(record.entity, record.id, record.json, record.updatedAt, deleted: record.deleted);
    return const PushResult.ok();
  }

  @override
  Future<PullPage> pull(SyncEntity entity, String? cursor) async {
    if (offline) throw const CloudOfflineException();
    final after = int.tryParse(cursor ?? '') ?? 0;
    final changed = rows[entity]!.entries.where((e) => e.value.seq > after).toList()
      ..sort((a, b) => a.value.seq.compareTo(b.value.seq));
    final records = [
      for (final e in changed)
        SyncRecord(
          entity: entity,
          id: e.key,
          updatedAt: e.value.clientUpdatedAt,
          json: e.value.deleted ? null : e.value.json,
          deleted: e.value.deleted,
        ),
    ];
    final last = changed.isEmpty ? cursor : '${changed.last.value.seq}';
    return PullPage(records: records, cursor: last, hasMore: false);
  }

  @override
  Future<void> deleteAllMyData() async {
    if (offline) throw const CloudOfflineException();
    for (final t in rows.values) {
      t.clear();
    }
  }

  @override
  Future<void> deleteAccount() async {
    if (offline) throw const CloudOfflineException();
    if (accountFunctionMissing) throw const CloudNotConfiguredException('delete-account isn’t deployed');
    await deleteAllMyData();
    deletedAccount = true;
  }
}
