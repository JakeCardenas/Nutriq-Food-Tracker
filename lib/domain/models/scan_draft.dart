import 'food_item.dart';

enum DraftStatus { analyzing, ready, failed }

/// A captured meal photo waiting to be reviewed. Drafts are saved on the
/// device so a slow or interrupted analysis never loses the meal.
class ScanDraft {
  const ScanDraft({
    required this.id,
    required this.photoPath,
    required this.createdAt,
    required this.status,
    this.items = const [],
    this.isDemo = false,
    this.sampleName,
    this.error,
  });

  final String id;
  final String photoPath;
  final DateTime createdAt;
  final DraftStatus status;
  final List<FoodItem> items;
  final bool isDemo;
  final String? sampleName;
  final String? error;

  ScanDraft copyWith({DraftStatus? status, List<FoodItem>? items, bool? isDemo, String? sampleName, String? error}) =>
      ScanDraft(
        id: id,
        photoPath: photoPath,
        createdAt: createdAt,
        status: status ?? this.status,
        items: items ?? this.items,
        isDemo: isDemo ?? this.isDemo,
        sampleName: sampleName ?? this.sampleName,
        error: error,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'photoPath': photoPath,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'status': status.name,
    'items': items.map((i) => i.toJson()).toList(),
    'isDemo': isDemo,
    'sampleName': sampleName,
    'error': error,
  };

  factory ScanDraft.fromJson(Map<String, Object?> j) => ScanDraft(
    id: j['id'] as String,
    photoPath: j['photoPath'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
    status: DraftStatus.values.asNameMap()[j['status']] ?? DraftStatus.failed,
    items: ((j['items'] as List?) ?? const [])
        .map((e) => FoodItem.fromJson((e as Map).cast<String, Object?>()))
        .toList(),
    isDemo: j['isDemo'] as bool? ?? false,
    sampleName: j['sampleName'] as String?,
    error: j['error'] as String?,
  );
}
