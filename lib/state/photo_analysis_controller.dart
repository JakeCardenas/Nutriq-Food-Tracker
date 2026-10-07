import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/local_store.dart';
import '../domain/photo_estimate_resolver.dart';
import '../services/food_analysis/food_analysis_service.dart';
import '../services/food_analysis/photo_estimate_backend.dart';
import '../services/food_analysis/photo_upload.dart';

enum CloudScanChoice { undecided, on, off }

/// Decides how a meal photo is analysed for one account on this phone:
/// on the device (or not at all) by default, or — only after the person
/// opted in — by the optional cloud photo estimate. Any cloud failure falls
/// back to the on-device result with a notice saying why.
class PhotoAnalysisController extends ChangeNotifier implements FoodAnalysisService {
  PhotoAnalysisController({
    required this.onDevice,
    this._cloud,
    this._store,
    Future<Uint8List> Function(Uint8List)? prepare,
  }) : _prepare = prepare ?? preparePhotoForUpload;

  final FoodAnalysisService onDevice;
  final PhotoEstimateBackend? _cloud;
  final LocalStore? _store;
  final Future<Uint8List> Function(Uint8List) _prepare;

  static const _key = 'scan_cloud';
  CloudScanChoice _choice = CloudScanChoice.undecided;
  bool _disposed = false;

  /// Signed in, in a build with photo estimates set up.
  bool get cloudAvailable => _cloud != null;
  bool get cloudEnabled => _cloud != null && _choice == CloudScanChoice.on;
  bool get needsCloudChoice => _cloud != null && _choice == CloudScanChoice.undecided;

  Future<void> load() async {
    _choice = switch (await _store?.readMeta(_key)) {
      'on' => CloudScanChoice.on,
      'off' => CloudScanChoice.off,
      _ => CloudScanChoice.undecided,
    };
    _notify();
  }

  Future<void> setCloudEnabled(bool enabled) async {
    _choice = enabled ? CloudScanChoice.on : CloudScanChoice.off;
    _notify();
    await _store?.writeMeta(_key, enabled ? 'on' : 'off');
  }

  @override
  bool get isDemo => !cloudEnabled && onDevice.isDemo;

  @override
  bool get recognizesPhotos => cloudEnabled || onDevice.recognizesPhotos;

  @override
  String get label => cloudEnabled ? 'Photo estimates (Gemini, opt-in)' : onDevice.label;

  @override
  Future<FoodAnalysisResult> analyze(Uint8List imageBytes) async {
    if (!cloudEnabled) return onDevice.analyze(imageBytes);
    final Uint8List jpeg;
    try {
      jpeg = await _prepare(imageBytes);
    } catch (_) {
      return _fallback(imageBytes, 'This photo couldn’t be prepared for upload, so it wasn’t sent.');
    }
    final Map<String, Object?> raw;
    try {
      raw = await _cloud!.estimate(jpeg);
    } on PhotoEstimateException catch (e) {
      return _fallback(imageBytes, noticeFor(e));
    } catch (_) {
      return _fallback(imageBytes, noticeFor(const PhotoEstimateException(PhotoEstimateFailure.failed)));
    }
    final estimate = PhotoEstimateResolver.fromResponse(raw);
    if (estimate == null) {
      return _fallback(imageBytes, noticeFor(const PhotoEstimateException(PhotoEstimateFailure.failed)));
    }
    return FoodAnalysisResult(
      items: const [],
      isDemo: false,
      estimate: estimate,
      notice: estimate.nutritionLookup == 'unavailable'
          ? 'The nutrition lookup was busy, so some foods may have no nutrition data — search for them instead.'
          : null,
    );
  }

  Future<FoodAnalysisResult> _fallback(Uint8List imageBytes, String why) async {
    if (!onDevice.recognizesPhotos) {
      return FoodAnalysisResult(items: const [], isDemo: false, notice: '$why Describe the meal instead.');
    }
    try {
      final r = await onDevice.analyze(imageBytes);
      return FoodAnalysisResult(
        items: r.items,
        isDemo: r.isDemo,
        sampleName: r.sampleName,
        suggestions: r.suggestions,
        notice: '$why Showing on-device suggestions instead.',
      );
    } catch (_) {
      return FoodAnalysisResult(items: const [], isDemo: false, notice: '$why Describe the meal instead.');
    }
  }

  /// Why the cloud estimate didn't happen, in plain words.
  static String noticeFor(PhotoEstimateException e) => switch (e.failure) {
    PhotoEstimateFailure.offline => 'Couldn’t reach Nutriq’s server for a photo estimate — check your connection.',
    PhotoEstimateFailure.signedOut => 'Sign in again to use photo estimates.',
    PhotoEstimateFailure.notSetUp => 'Photo estimates aren’t set up on the server yet.',
    PhotoEstimateFailure.dailyLimit =>
      'You’ve used today’s ${e.limit == null ? '' : '${e.limit} '}photo estimates'
          '${e.resetsAt == null ? '' : ' — more from ${DateFormat.jm().format(e.resetsAt!.toLocal())}'}.',
    PhotoEstimateFailure.providerBusy => 'The photo estimate service has reached its free limit for now.',
    PhotoEstimateFailure.timeout => 'The photo estimate took too long.',
    PhotoEstimateFailure.rejected => 'The photo couldn’t be sent for an estimate.',
    PhotoEstimateFailure.failed => 'Couldn’t get a photo estimate just now.',
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
