import 'dart:typed_data';

import 'food_analysis_service.dart';

/// The default: Nutriq doesn't recognise food in photos (that needs a vision
/// model on a server). A photo is kept with the meal and the person types
/// what's in it; the built-in food list fills in the numbers.
class NoPhotoRecognitionService implements FoodAnalysisService {
  const NoPhotoRecognitionService();

  @override
  bool get isDemo => false;

  @override
  bool get recognizesPhotos => false;

  @override
  String get label => 'Describe it · food list';

  @override
  Future<FoodAnalysisResult> analyze(Uint8List imageBytes) =>
      Future.error(const FoodAnalysisException('photo recognition isn’t available'));
}
