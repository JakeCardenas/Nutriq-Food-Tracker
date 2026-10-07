import '../food_catalog.dart';

/// A food that *might* be in a meal photo, from the iPhone's general image
/// recognizer. It is only a suggestion: nothing is added to a meal until the
/// person picks it and chooses the serving.
class PhotoSuggestion {
  const PhotoSuggestion({required this.label, required this.searchTerm, this.foodName});

  /// What the recognizer's label means, in plain words ("Fried egg").
  final String label;

  /// What to search Nutriq's food list for when the label could be several foods.
  final String searchTerm;

  /// A single matching food in Nutriq's list, only when the label names exactly that food.
  final String? foodName;

  CatalogFood? get food => foodName == null ? null : FoodCatalog.byAlias(foodName!);

  Map<String, Object?> toJson() => {'label': label, 'searchTerm': searchTerm, 'foodName': foodName};

  factory PhotoSuggestion.fromJson(Map<String, Object?> j) => PhotoSuggestion(
    label: j['label'] as String,
    searchTerm: j['searchTerm'] as String,
    foodName: j['foodName'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is PhotoSuggestion && other.label == label && other.searchTerm == searchTerm && other.foodName == foodName;

  @override
  int get hashCode => Object.hash(label, searchTerm, foodName);
}
