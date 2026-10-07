import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/photo_food_mapper.dart';
import 'food_analysis_service.dart';

/// Suggests foods with the iPhone's built-in, general-purpose image
/// classifier (Apple Vision), on the device: the photo never leaves the phone
/// and nothing is paid for. Vision isn't a food model and can be wrong, so
/// the result is only a few suggestions — no foods, no portions. The person
/// picks what they ate and chooses each serving.
class OnDeviceFoodAnalysisService implements FoodAnalysisService {
  OnDeviceFoodAnalysisService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.prodbyjake.nutriq/food_vision');

  final MethodChannel _channel;

  @override
  bool get isDemo => false;

  @override
  bool get recognizesPhotos => true;

  @override
  String get label => 'Suggestions on this iPhone';

  @override
  Future<FoodAnalysisResult> analyze(Uint8List imageBytes) async {
    final List<Object?>? raw;
    try {
      raw = await _channel
          .invokeListMethod<Object?>('classify', {'image': imageBytes})
          .timeout(const Duration(seconds: 20));
    } on MissingPluginException {
      throw const FoodAnalysisException('photo recognition isn’t available on this device');
    } on PlatformException {
      throw const FoodAnalysisException('the iPhone couldn’t read this photo');
    } on TimeoutException {
      throw const FoodAnalysisException('it took too long');
    }
    final labels = <VisionLabel>[
      for (final r in raw ?? const [])
        if (r case {'label': final String label, 'confidence': final num confidence})
          (label: label, confidence: confidence.toDouble(), meetsPrecision: r['meetsPrecision'] == true),
    ];
    return FoodAnalysisResult(items: const [], suggestions: PhotoFoodMapper.suggestions(labels), isDemo: false);
  }
}
