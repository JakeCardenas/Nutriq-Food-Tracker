import 'dart:typed_data';

import '../../domain/models/food_item.dart';
import '../../domain/models/photo_estimate.dart';
import '../../domain/models/photo_suggestion.dart';

/// Turns a meal photo into suggested foods.
///
/// A real implementation should call **your own backend** (which keeps any
/// AI-provider key on the server). Never ship provider keys in the app.
abstract interface class FoodAnalysisService {
  /// True when results are samples rather than real photo analysis.
  bool get isDemo;

  /// False when photos aren't analysed at all: the person describes the meal
  /// instead, and no scan draft is created.
  bool get recognizesPhotos;

  /// Short name shown in Settings → About.
  String get label;

  /// Throws [FoodAnalysisException] when analysis can't be completed.
  Future<FoodAnalysisResult> analyze(Uint8List imageBytes);
}

class FoodAnalysisResult {
  const FoodAnalysisResult({
    required this.items,
    required this.isDemo,
    this.sampleName,
    this.suggestions = const [],
    this.estimate,
    this.notice,
  });

  /// Foods with nutrition, pre-filled in the review (demo samples).
  final List<FoodItem> items;

  /// Foods the photo might contain, for the person to choose from (on-device recognition).
  final List<PhotoSuggestion> suggestions;

  /// The optional cloud photo estimate (candidate foods with nutrition sources), for review.
  final PhotoEstimate? estimate;

  /// Why the result is limited, shown in the review.
  final String? notice;
  final bool isDemo;

  /// Name of the demo sample used, for the demo banner.
  final String? sampleName;
}

class FoodAnalysisException implements Exception {
  const FoodAnalysisException(this.message);
  final String message;

  @override
  String toString() => 'FoodAnalysisException: $message';
}
