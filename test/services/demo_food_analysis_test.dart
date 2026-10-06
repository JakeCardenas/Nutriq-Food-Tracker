import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/services/food_analysis/demo_food_analysis_service.dart';
import 'package:nutriq/services/food_analysis/food_analysis_service.dart';

void main() {
  final service = DemoFoodAnalysisService(delay: Duration.zero);
  final photoA = Uint8List.fromList(List.generate(5000, (i) => (i * 7) % 256));
  final photoB = Uint8List.fromList(List.generate(5000, (i) => (i * 13 + 5) % 256));

  test('is labeled as demo', () async {
    expect(service.isDemo, isTrue);
    final result = await service.analyze(photoA);
    expect(result.isDemo, isTrue);
    expect(result.sampleName, isNotEmpty);
    expect(result.items, isNotEmpty);
  });

  test('the same photo always gets the same sample', () async {
    final first = await service.analyze(photoA);
    final second = await service.analyze(photoA);
    expect(second.sampleName, first.sampleName);
    expect(second.items.map((i) => i.name), first.items.map((i) => i.name));
  });

  test('item ids are unique per analysis so edits never collide', () async {
    final first = await service.analyze(photoA);
    final second = await service.analyze(photoA);
    expect(first.items.first.id, isNot(second.items.first.id));
  });

  test('different photos can map to different samples', () async {
    final names = <String?>{};
    for (var seed = 0; seed < 40; seed++) {
      final bytes = Uint8List.fromList(List.generate(800, (i) => (i * seed + seed) % 256));
      names.add((await service.analyze(bytes)).sampleName);
    }
    expect(names.length, greaterThan(3));
    expect((await service.analyze(photoB)).items, isNotEmpty);
  });

  test('empty image data is an error', () {
    expect(service.analyze(Uint8List(0)), throwsA(isA<FoodAnalysisException>()));
  });

  test('demo results carry no confidence so the UI never implies recognition', () async {
    final result = await service.analyze(photoA);
    expect(result.items.every((i) => i.confidence == null), isTrue);
  });
}
