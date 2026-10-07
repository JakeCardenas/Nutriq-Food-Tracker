import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/domain/models/photo_estimate.dart';
import 'package:nutriq/domain/models/photo_suggestion.dart';
import 'package:nutriq/services/food_analysis/food_analysis_service.dart';
import 'package:nutriq/services/food_analysis/no_photo_recognition_service.dart';
import 'package:nutriq/services/food_analysis/photo_estimate_backend.dart';
import 'package:nutriq/services/food_analysis/photo_upload.dart';
import 'package:nutriq/state/photo_analysis_controller.dart';

import '../support/memory_local_store.dart';

/// On-device suggestions, like the iPhone recognizer.
class _OnDevice implements FoodAnalysisService {
  int calls = 0;
  @override
  bool get isDemo => false;
  @override
  bool get recognizesPhotos => true;
  @override
  String get label => 'On-device';
  @override
  Future<FoodAnalysisResult> analyze(Uint8List imageBytes) async {
    calls++;
    return const FoodAnalysisResult(
      items: [],
      isDemo: false,
      suggestions: [PhotoSuggestion(label: 'Rice', searchTerm: 'rice')],
    );
  }
}

class _Backend implements PhotoEstimateBackend {
  final sent = <Uint8List>[];
  PhotoEstimateException? error;
  Map<String, Object?> response = {
    'isFood': true,
    'dish': 'Tuna and rice',
    'dishAlternatives': <String>[],
    'foods': [
      {
        'name': 'white rice, cooked',
        'localName': 'kanin',
        'visibility': 'visible',
        'grams': {'low': 250, 'high': 330, 'note': 'about 2 cups'},
        'fdc': null,
      },
    ],
    'uncertainties': <String>[],
    'remaining': 9,
    'nutritionLookup': 'fdc',
  };

  @override
  Future<Map<String, Object?>> estimate(Uint8List jpeg) async {
    sent.add(jpeg);
    if (error != null) throw error!;
    return response;
  }
}

void main() {
  final original = Uint8List.fromList([1, 2, 3]);
  final prepared = Uint8List.fromList([9, 9]);
  late MemoryLocalStore store;
  late _OnDevice onDevice;
  late _Backend backend;
  late List<Uint8List> prepCalls;

  PhotoAnalysisController controller({FoodAnalysisService? local, bool withCloud = true, bool prepFails = false}) =>
      PhotoAnalysisController(
        onDevice: local ?? onDevice,
        cloud: withCloud ? backend : null,
        store: store,
        prepare: (bytes) async {
          prepCalls.add(bytes);
          if (prepFails) throw const PhotoPrepException('bad');
          return prepared;
        },
      );

  setUp(() {
    store = MemoryLocalStore();
    onDevice = _OnDevice();
    backend = _Backend();
    prepCalls = [];
  });

  test('without the cloud path it is exactly the on-device recognizer', () async {
    final c = controller(withCloud: false);
    await c.load();
    expect(c.cloudAvailable, isFalse);
    expect(c.needsCloudChoice, isFalse);
    expect(c.recognizesPhotos, isTrue);
    expect(c.label, 'On-device');
    final r = await c.analyze(original);
    expect(r.suggestions.single.label, 'Rice');
    expect(r.estimate, isNull);
  });

  test('nothing is uploaded until the person agrees', () async {
    final c = controller();
    await c.load();
    expect(c.needsCloudChoice, isTrue);
    await c.analyze(original);
    expect(backend.sent, isEmpty);
    expect(prepCalls, isEmpty);
    expect(onDevice.calls, 1);

    await c.setCloudEnabled(false);
    await c.analyze(original);
    expect(backend.sent, isEmpty, reason: 'declined stays declined');
  });

  test('the choice is remembered for this account on this phone', () async {
    await controller().setCloudEnabled(true);
    expect(await store.readMeta('scan_cloud'), 'on');
    final again = controller();
    await again.load();
    expect(again.cloudEnabled, isTrue);
    expect(again.needsCloudChoice, isFalse);
  });

  test('when on: uploads only the prepared copy and returns an estimate, no items', () async {
    final c = controller();
    await c.setCloudEnabled(true);
    final r = await c.analyze(original);
    expect(prepCalls.single, original);
    expect(backend.sent.single, prepared, reason: 'never the original photo');
    expect(r.items, isEmpty);
    expect(r.isDemo, isFalse);
    expect(r.notice, isNull);
    final rice = r.estimate!.foods.single;
    expect(rice.source, NutritionSource.catalog);
    expect(rice.suggestedGrams, 290);
    expect(c.label, contains('Gemini'));
  });

  test('if the photo can’t be prepared, nothing is uploaded and it falls back', () async {
    final c = controller(prepFails: true);
    await c.setCloudEnabled(true);
    final r = await c.analyze(original);
    expect(backend.sent, isEmpty);
    expect(r.suggestions.single.label, 'Rice');
    expect(r.notice, contains('wasn’t sent'));
  });

  group('when the cloud estimate fails, the person still gets something honest', () {
    Future<FoodAnalysisResult> failWith(PhotoEstimateException e, {FoodAnalysisService? local}) async {
      backend.error = e;
      final c = controller(local: local);
      await c.setCloudEnabled(true);
      return c.analyze(original);
    }

    test('offline on iPhone → on-device suggestions + notice', () async {
      final r = await failWith(const PhotoEstimateException(PhotoEstimateFailure.offline));
      expect(r.estimate, isNull);
      expect(r.suggestions.single.label, 'Rice');
      expect(r.notice, contains('Couldn’t reach Nutriq’s server'));
      expect(r.notice, isNot(contains('wasn’t sent')), reason: 'the upload may have finished before the drop');
      expect(r.notice, contains('on-device suggestions'));
    });

    test('offline without an on-device recognizer (Android) → describe it', () async {
      final r = await failWith(
        const PhotoEstimateException(PhotoEstimateFailure.offline),
        local: const NoPhotoRecognitionService(),
      );
      expect(r.suggestions, isEmpty);
      expect(r.items, isEmpty);
      expect(r.notice, contains('Describe'));
    });

    test('daily limit says how many and when more are available', () async {
      final r = await failWith(
        PhotoEstimateException(PhotoEstimateFailure.dailyLimit, limit: 10, resetsAt: DateTime.utc(2026, 10, 8)),
      );
      expect(r.notice, startsWith('You’ve used today’s 10 photo estimates'));
    });

    test('provider quota and not-set-up are explained', () async {
      expect(
        (await failWith(const PhotoEstimateException(PhotoEstimateFailure.providerBusy))).notice,
        contains('free limit'),
      );
      expect(
        (await failWith(const PhotoEstimateException(PhotoEstimateFailure.notSetUp))).notice,
        contains('aren’t set up'),
      );
    });
  });

  test('if USDA lookups were busy, the review says some foods may lack nutrition', () async {
    backend.response = {...backend.response, 'nutritionLookup': 'unavailable'};
    final c = controller();
    await c.setCloudEnabled(true);
    expect((await c.analyze(original)).notice, contains('nutrition'));
  });

  test('Android only recognizes photos when the cloud path is on', () async {
    final c = controller(local: const NoPhotoRecognitionService());
    await c.load();
    expect(c.recognizesPhotos, isFalse);
    await c.setCloudEnabled(true);
    expect(c.recognizesPhotos, isTrue);
    await c.setCloudEnabled(false);
    expect(c.recognizesPhotos, isFalse);
  });
}
