import 'food_item.dart';

/// A food kept in "My foods" for quick re-use — saved without logging a meal.
class SavedFood {
  const SavedFood({required this.id, required this.item, required this.savedAt});

  final String id;

  /// Template with `servings == 1`.
  final FoodItem item;
  final DateTime savedAt;

  Map<String, Object?> toJson() => {'id': id, 'item': item.toJson(), 'savedAt': savedAt.millisecondsSinceEpoch};

  factory SavedFood.fromJson(Map<String, Object?> j) => SavedFood(
    id: j['id'] as String,
    item: FoodItem.fromJson((j['item'] as Map).cast<String, Object?>()),
    savedAt: DateTime.fromMillisecondsSinceEpoch(j['savedAt'] as int),
  );

  @override
  bool operator ==(Object other) =>
      other is SavedFood && other.id == id && other.item == item && other.savedAt == savedAt;

  @override
  int get hashCode => Object.hash(id, item, savedAt);
}
