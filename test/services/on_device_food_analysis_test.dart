import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/services/food_analysis/food_analysis_service.dart';
import 'package:nutriq/services/food_analysis/on_device_food_analysis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.prodbyjake.nutriq/food_vision');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final photo = Uint8List.fromList(List.filled(32, 1));
  final service = OnDeviceFoodAnalysisService();

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('runs on the device and is not a demo', () {
    expect(service.isDemo, isFalse);
    expect(service.recognizesPhotos, isTrue);
  });

  test('sends the photo to iOS and returns suggestions — never foods or portions', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return [
        {'label': 'rice', 'confidence': 0.8, 'meetsPrecision': true},
        {'label': 'fried_egg', 'confidence': 0.6, 'meetsPrecision': true},
        {'label': 'banana', 'confidence': 0.9, 'meetsPrecision': false},
        {'label': 'table', 'confidence': 0.9, 'meetsPrecision': true},
      ];
    });
    final result = await service.analyze(photo);
    expect(received!.method, 'classify');
    expect((received!.arguments as Map)['image'], photo);
    expect(result.isDemo, isFalse);
    expect(result.items, isEmpty);
    expect(result.suggestions.map((s) => s.label), ['Rice', 'Fried egg']);
  });

  test('labels without the precision flag are not suggested', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => [
        {'label': 'banana', 'confidence': 0.95},
      ],
    );
    expect((await service.analyze(photo)).suggestions, isEmpty);
  });

  test('no food in the photo → no foods (the review asks what it was)', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => [
        {'label': 'dog', 'confidence': 0.9},
      ],
    );
    final result = await service.analyze(photo);
    expect(result.items, isEmpty);
    expect(result.suggestions, isEmpty);
  });

  test('iOS errors become a retryable analysis failure', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'vision_failed'));
    await expectLater(service.analyze(photo), throwsA(isA<FoodAnalysisException>()));
  });

  test('no recognizer on this device (e.g. Android) is a clear failure', () async {
    await expectLater(service.analyze(photo), throwsA(isA<FoodAnalysisException>()));
  });
}
