import 'dart:typed_data';

import '../../domain/ids.dart';
import '../../domain/models/food_item.dart';
import 'demo_samples.dart';
import 'food_analysis_service.dart';

/// Demo-only analyzer: returns one of a few sample meals so friends can try
/// the review flow. It does **not** look at the photo's content and never
/// uploads anything. The sample is chosen from the photo bytes so the same
/// photo always gets the same sample (no confusing "different answer on
/// re-scan" in demos).
class DemoFoodAnalysisService implements FoodAnalysisService {
  DemoFoodAnalysisService({this.delay = const Duration(milliseconds: 1600)});

  final Duration delay;

  @override
  bool get isDemo => true;

  @override
  String get label => 'Demo analyzer (sample results)';

  @override
  Future<FoodAnalysisResult> analyze(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) {
      throw const FoodAnalysisException('The photo could not be read.');
    }
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final sample = demoSampleMeals[_fingerprint(imageBytes) % demoSampleMeals.length];
    return FoodAnalysisResult(
      isDemo: true,
      sampleName: sample.name,
      items: [
        for (final f in sample.foods)
          FoodItem(
            id: newId(),
            name: f.name,
            servings: f.servings,
            servingLabel: f.serving,
            caloriesPerServing: f.kcal,
            proteinPerServing: f.protein,
            carbsPerServing: f.carbs,
            fatPerServing: f.fat,
          ),
      ],
    );
  }

  /// FNV-1a over an evenly spaced sample of bytes (fast on large photos),
  /// finished with murmur3's fmix32 so the low bits used by `%` are well mixed.
  static int _fingerprint(Uint8List bytes) {
    const maxSamples = 4096;
    final step = bytes.length <= maxSamples ? 1 : bytes.length ~/ maxSamples;
    var hash = 0x811c9dc5;
    for (var i = 0; i < bytes.length; i += step) {
      hash ^= bytes[i];
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    hash ^= hash >> 16;
    hash = (hash * 0x85ebca6b) & 0xFFFFFFFF;
    hash ^= hash >> 13;
    hash = (hash * 0xc2b2ae35) & 0xFFFFFFFF;
    hash ^= hash >> 16;
    return hash;
  }
}
