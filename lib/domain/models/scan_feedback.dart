enum FeedbackRating {
  tooHigh('Too high'),
  aboutRight('About right'),
  tooLow('Too low');

  const FeedbackRating(this.label);
  final String label;
}

/// A tester's quick judgement of a scan estimate. Stored only on the device.
class ScanFeedback {
  const ScanFeedback({
    required this.id,
    required this.mealId,
    required this.mealSummary,
    required this.estimatedCalories,
    required this.rating,
    required this.wasDemo,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String? mealId;
  final String mealSummary;
  final int estimatedCalories;
  final FeedbackRating rating;
  final bool wasDemo;
  final DateTime createdAt;
  final String? note;

  Map<String, Object?> toJson() => {
    'id': id,
    'mealId': mealId,
    'mealSummary': mealSummary,
    'estimatedCalories': estimatedCalories,
    'rating': rating.name,
    'wasDemo': wasDemo,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'note': note,
  };

  factory ScanFeedback.fromJson(Map<String, Object?> j) => ScanFeedback(
    id: j['id'] as String,
    mealId: j['mealId'] as String?,
    mealSummary: j['mealSummary'] as String,
    estimatedCalories: j['estimatedCalories'] as int,
    rating: FeedbackRating.values.byName(j['rating'] as String),
    wasDemo: j['wasDemo'] as bool,
    createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
    note: j['note'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is ScanFeedback &&
      other.id == id &&
      other.mealId == mealId &&
      other.mealSummary == mealSummary &&
      other.estimatedCalories == estimatedCalories &&
      other.rating == rating &&
      other.wasDemo == wasDemo &&
      other.createdAt == createdAt &&
      other.note == note;

  @override
  int get hashCode => Object.hash(id, mealId, mealSummary, estimatedCalories, rating, wasDemo, createdAt, note);
}
