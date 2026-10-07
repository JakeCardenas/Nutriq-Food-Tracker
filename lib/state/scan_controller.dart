import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../domain/ids.dart';
import '../domain/models/scan_draft.dart';
import '../services/food_analysis/food_analysis_service.dart';
import '../services/photo_service.dart';

/// Scan drafts: every captured photo is saved as a draft *before* analysis
/// starts, so a slow, failed or interrupted analysis never loses the meal.
/// Nothing is logged until the person reviews the draft.
class ScanController extends ChangeNotifier {
  ScanController({required this.store, required this.analysis, required this.photos, this.photoInUse});

  final LocalStore store;
  final FoodAnalysisService analysis;
  final PhotoService photos;

  /// True when a logged meal uses this photo — discarding a draft then keeps the file.
  final bool Function(String photoPath)? photoInUse;

  List<ScanDraft> _drafts = [];
  final Set<Future<void>> _inFlight = {};
  bool _disposed = false;

  /// Newest first.
  List<ScanDraft> get drafts => List.unmodifiable(_drafts);

  Future<void> load() async {
    final stored = await store.scanDrafts();
    _drafts = [];
    for (final d in stored) {
      if (d.status == DraftStatus.analyzing) {
        final interrupted = d.copyWith(
          status: DraftStatus.failed,
          error: 'The analysis was interrupted when the app closed. Tap Retry.',
        );
        await store.upsertDraft(interrupted);
        _drafts.add(interrupted);
      } else {
        _drafts.add(d);
      }
    }
    _notify();
  }

  Future<ScanDraft> startScan(String storedPhotoPath) async {
    final draft = ScanDraft(
      id: newId(),
      photoPath: storedPhotoPath,
      createdAt: DateTime.now(),
      status: DraftStatus.analyzing,
      isDemo: analysis.isDemo,
    );
    await _save(draft);
    _track(_analyze(draft));
    return draft;
  }

  Future<void> retry(String id) async {
    final draft = _byId(id);
    if (draft == null || draft.status == DraftStatus.analyzing) return;
    final again = draft.copyWith(status: DraftStatus.analyzing);
    await _save(again);
    _track(_analyze(again));
  }

  Future<void> _analyze(ScanDraft draft) async {
    ScanDraft result;
    try {
      final bytes = await photos.readBytes(draft.photoPath);
      final r = await analysis.analyze(bytes);
      result = draft.copyWith(
        status: DraftStatus.ready,
        items: r.items,
        suggestions: r.suggestions,
        estimate: r.estimate,
        notice: r.notice,
        isDemo: r.isDemo,
        sampleName: r.sampleName,
      );
    } on FoodAnalysisException catch (e) {
      result = draft.copyWith(status: DraftStatus.failed, error: 'Couldn’t estimate this photo (${e.message}).');
    } catch (_) {
      result = draft.copyWith(status: DraftStatus.failed, error: 'Couldn’t estimate this photo.');
    }
    if (_byId(draft.id) == null) return; // discarded meanwhile
    await _save(result);
  }

  /// Removes the draft and its photo (nothing was logged). An analysis still
  /// running for it can't bring it back, and a photo that a logged meal uses
  /// is kept.
  Future<void> discard(String id) async {
    final draft = _byId(id);
    if (draft == null) return;
    _drafts = _drafts.where((d) => d.id != id).toList();
    _notify();
    await store.deleteDraft(id);
    if (photoInUse?.call(draft.photoPath) ?? false) return;
    await photos.delete(draft.photoPath);
  }

  /// The draft became a logged meal (which now owns the photo).
  Future<void> markLogged(String id) async {
    _drafts = _drafts.where((d) => d.id != id).toList();
    _notify();
    await store.deleteDraft(id);
  }

  ScanDraft? _byId(String id) {
    for (final d in _drafts) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<void> _save(ScanDraft draft) async {
    final index = _drafts.indexWhere((d) => d.id == draft.id);
    if (index >= 0) {
      _drafts = [..._drafts]..[index] = draft;
    } else {
      _drafts = [draft, ..._drafts];
    }
    _notify();
    await store.upsertDraft(draft);
  }

  void _track(Future<void> f) {
    _inFlight.add(f);
    f.whenComplete(() => _inFlight.remove(f));
  }

  /// Completes when no analysis is running (used by tests).
  Future<void> waitForIdle() async {
    while (_inFlight.isNotEmpty) {
      await Future.wait(_inFlight.toList());
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
