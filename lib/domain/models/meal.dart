import 'package:flutter/foundation.dart';

import 'food_item.dart';
import 'nutrition.dart';

enum MealType {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  snack('Snack');

  const MealType(this.label);
  final String label;

  static MealType suggestFor(DateTime t) {
    final h = t.hour;
    if (h >= 4 && h < 11) return breakfast;
    if (h >= 11 && h < 15) return lunch;
    if (h >= 17 && h < 22) return dinner;
    return snack;
  }
}

/// Where a meal's foods came from. Kept so the UI can label demo results.
enum MealSource { demoScan, scan, manual }

class Meal {
  const Meal({
    required this.id,
    required this.loggedAt,
    required this.type,
    required this.source,
    required this.items,
    this.photoPath,
    this.note,
    this.name,
  });

  final String id;
  final DateTime loggedAt;
  final MealType type;
  final MealSource source;
  final List<FoodItem> items;
  final String? photoPath;
  final String? note;

  /// Optional user-facing name ("Chicken bowl"); falls back to the meal type.
  final String? name;

  NutritionTotals get totals => NutritionTotals.sum(items.map((i) => i.totals));

  String get title => (name?.trim().isNotEmpty ?? false) ? name!.trim() : type.label;

  String get itemSummary => items.map((i) => i.name).join(', ');

  Meal copyWith({
    DateTime? loggedAt,
    MealType? type,
    List<FoodItem>? items,
    String? note,
    String? name,
    String? photoPath,
  }) => Meal(
    id: id,
    loggedAt: loggedAt ?? this.loggedAt,
    type: type ?? this.type,
    source: source,
    items: items ?? this.items,
    photoPath: photoPath ?? this.photoPath,
    note: note ?? this.note,
    name: name ?? this.name,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'loggedAt': loggedAt.millisecondsSinceEpoch,
    'type': type.name,
    'source': source.name,
    'items': items.map((i) => i.toJson()).toList(),
    'photoPath': photoPath,
    'note': note,
    'name': name,
  };

  factory Meal.fromJson(Map<String, Object?> j) => Meal(
    id: j['id'] as String,
    loggedAt: DateTime.fromMillisecondsSinceEpoch(j['loggedAt'] as int),
    type: MealType.values.byName(j['type'] as String),
    source: MealSource.values.byName(j['source'] as String),
    items: (j['items'] as List).map((e) => FoodItem.fromJson((e as Map).cast<String, Object?>())).toList(),
    photoPath: j['photoPath'] as String?,
    note: j['note'] as String?,
    name: j['name'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is Meal &&
      other.id == id &&
      other.loggedAt == loggedAt &&
      other.type == type &&
      other.source == source &&
      listEquals(other.items, items) &&
      other.photoPath == photoPath &&
      other.note == note &&
      other.name == name;

  @override
  int get hashCode => Object.hash(id, loggedAt, type, source, Object.hashAll(items), photoPath, note, name);
}
