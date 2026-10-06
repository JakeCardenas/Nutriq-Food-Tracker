import '../domain/ids.dart';
import '../domain/models/meal.dart';
import 'cloud_repository.dart';
import 'local_store.dart';
import 'sync_models.dart';

class SyncReport {
  const SyncReport({this.pushed = 0, this.pulled = 0, this.conflicts = 0, this.rejected = const []});
  final int pushed;
  final int pulled;
  final int conflicts;

  /// Server refusals ("Lunch: value out of range"); those records stay pending.
  final List<String> rejected;
}

/// Two-way sync for one signed-in account's local file.
///
/// 1. **Push** every pending record. The server refuses stale writes; the newer
///    server version is applied locally and the local edit is saved as a
///    visible [SyncConflict] so nothing is lost silently.
/// 2. **Pull** server changes since the last cursor, skipping rows that were
///    edited locally during this sync (they'll push next time). Meal photos
///    stay on the device, so a pulled meal keeps this phone's photo link.
///
/// Network failures throw [CloudOfflineException] and leave everything pending.
class SyncEngine {
  SyncEngine({required this.store, required this.cloud, this.onMealPhotoOrphaned});

  final LocalStore store;
  final CloudRepository cloud;

  /// Called with a photo path whose meal was deleted on another device.
  final void Function(String photoPath)? onMealPhotoOrphaned;

  static const _pullOrder = [SyncEntity.profile, SyncEntity.meal, SyncEntity.savedFood, SyncEntity.scanFeedback];

  Future<SyncReport> sync() async {
    var pushed = 0, pulled = 0, conflicts = 0;
    final rejected = <String>[];

    for (final record in await store.pendingRecords()) {
      final PushResult result;
      try {
        result = await cloud.push(record);
      } on CloudRejectedException catch (e) {
        rejected.add('${_describe(record.entity, record.json, record.id)}: ${e.message}');
        continue;
      }
      if (!result.stale) {
        await store.markSynced(record);
        pushed++;
        continue;
      }
      conflicts++;
      await store.addConflict(
        SyncConflict(
          id: newId(),
          entity: record.entity,
          entityId: record.id,
          createdAt: DateTime.now(),
          summary:
              '${_describe(record.entity, record.json, record.id)} — your ${record.deleted ? 'deletion' : 'edit'} '
              'from this phone was replaced by a newer change',
          discardedJson: record.json,
        ),
      );
      final current = result.current;
      if (current != null) await _applyRemote(current);
    }

    for (final entity in _pullOrder) {
      final cursorKey = 'sync:cursor:${entity.name}';
      var cursor = await store.readMeta(cursorKey);
      while (true) {
        final page = await cloud.pull(entity, cursor);
        for (final remote in page.records) {
          final local = await store.record(remote.entity, remote.id);
          if (local != null && local.pending) continue;
          await _applyRemote(remote);
          pulled++;
        }
        cursor = page.cursor;
        await store.writeMeta(cursorKey, cursor);
        if (!page.hasMore) break;
      }
    }

    return SyncReport(pushed: pushed, pulled: pulled, conflicts: conflicts, rejected: rejected);
  }

  Future<void> _applyRemote(SyncRecord remote) async {
    if (remote.entity != SyncEntity.meal) return store.applyRemote(remote);
    final local = await store.record(SyncEntity.meal, remote.id);
    final localPhoto = local?.json?['photoPath'] as String?;
    if (remote.deleted || remote.json == null) {
      await store.applyRemote(remote);
      if (localPhoto != null) onMealPhotoOrphaned?.call(localPhoto);
      return;
    }
    final json = {...remote.json!};
    if (localPhoto != null) json['photoPath'] = localPhoto;
    await store.applyRemote(SyncRecord(entity: remote.entity, id: remote.id, updatedAt: remote.updatedAt, json: json));
  }

  static String _describe(SyncEntity entity, Map<String, Object?>? json, String id) {
    if (json == null) return entity.label;
    try {
      return switch (entity) {
        SyncEntity.profile => 'Profile & goals',
        SyncEntity.meal => () {
          final meal = Meal.fromJson(json);
          return '${meal.title} · ${meal.loggedAt.month}/${meal.loggedAt.day}';
        }(),
        SyncEntity.savedFood => ((json['item'] as Map?)?['name'] as String?) ?? 'Saved food',
        SyncEntity.scanFeedback => 'Scan feedback',
      };
    } catch (_) {
      return '${entity.label} $id';
    }
  }
}
