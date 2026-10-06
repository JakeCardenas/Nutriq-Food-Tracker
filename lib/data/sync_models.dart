/// Records exchanged between the local store and the cloud.
library;

enum SyncEntity {
  profile('profile'),
  meal('meal'),
  savedFood('saved food'),
  scanFeedback('scan feedback');

  const SyncEntity(this.label);
  final String label;
}

/// One row as the sync engine sees it. [json] is the app model's JSON
/// (null for deletions). [updatedAt] is the client edit time in ms.
class SyncRecord {
  const SyncRecord({
    required this.entity,
    required this.id,
    required this.updatedAt,
    this.json,
    this.deleted = false,
    this.pending = false,
  });

  final SyncEntity entity;
  final String id;
  final int updatedAt;
  final Map<String, Object?>? json;
  final bool deleted;

  /// True when this row has a local edit that hasn't been uploaded yet.
  final bool pending;

  @override
  String toString() => 'SyncRecord(${entity.name}:$id @$updatedAt${deleted ? ' deleted' : ''})';
}

/// A local edit that lost to a newer edit from another device. Kept so the
/// person can look at it and restore it — conflicts are never silent.
class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.createdAt,
    required this.summary,
    this.discardedJson,
  });

  final String id;
  final SyncEntity entity;
  final String entityId;
  final DateTime createdAt;

  /// Human-readable description, e.g. "Lunch · Oct 6 (your edit from this phone)".
  final String summary;

  /// The local version that was replaced (null if it was a deletion).
  final Map<String, Object?>? discardedJson;

  Map<String, Object?> toJson() => {
    'id': id,
    'entity': entity.name,
    'entityId': entityId,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'summary': summary,
    'discarded': discardedJson,
  };

  factory SyncConflict.fromJson(Map<String, Object?> j) => SyncConflict(
    id: j['id'] as String,
    entity: SyncEntity.values.byName(j['entity'] as String),
    entityId: j['entityId'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
    summary: j['summary'] as String,
    discardedJson: (j['discarded'] as Map?)?.cast<String, Object?>(),
  );
}
