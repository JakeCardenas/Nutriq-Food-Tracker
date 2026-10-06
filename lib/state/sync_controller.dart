import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/cloud_repository.dart';
import '../data/local_store.dart';
import '../data/sync_engine.dart';
import '../data/sync_models.dart';
import '../domain/models/meal.dart';
import '../domain/models/saved_food.dart';
import '../domain/models/scan_feedback.dart';
import '../domain/models/settings.dart';
import '../domain/models/user_profile.dart';

enum SyncState { idle, syncing, synced, offline, error }

/// Runs [SyncEngine] for a signed-in account and exposes status for the UI:
/// synced / syncing / offline (changes kept on the phone) / error, the number
/// of pending changes, and conflicts the person can review and restore.
class SyncController extends ChangeNotifier {
  SyncController({
    required this.engine,
    required this.store,
    required this.onPulled,
    this.debounce = const Duration(seconds: 2),
    this.retryDelays = const [Duration(seconds: 30), Duration(minutes: 2), Duration(minutes: 5)],
  });

  final SyncEngine engine;
  final LocalStore store;

  /// Reloads controllers after server changes were applied locally.
  final Future<void> Function() onPulled;
  final Duration debounce;
  final List<Duration> retryDelays;

  SyncState _state = SyncState.idle;
  String? _message;
  DateTime? _lastSyncedAt;
  int _pending = 0;
  List<SyncConflict> _conflicts = const [];
  Timer? _debounceTimer;
  Timer? _retryTimer;
  int _retryIndex = 0;
  Future<void>? _running;
  bool _disposed = false;

  SyncState get state => _state;
  String? get message => _message;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int get pending => _pending;
  List<SyncConflict> get conflicts => _conflicts;

  Future<void> refreshCounts() async {
    _pending = await store.pendingCount();
    _conflicts = await store.conflicts();
    _notify();
  }

  /// Debounced sync after local edits.
  void scheduleSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => syncNow());
  }

  Future<void> syncNow() => _running ??= _run().whenComplete(() => _running = null);

  Future<void> _run() async {
    _retryTimer?.cancel();
    _state = SyncState.syncing;
    _notify();
    try {
      final report = await engine.sync();
      if (report.pulled > 0 || report.conflicts > 0) await onPulled();
      _lastSyncedAt = DateTime.now();
      _retryIndex = 0;
      if (report.rejected.isNotEmpty) {
        _state = SyncState.error;
        final n = report.rejected.length;
        _message =
            '$n ${n == 1 ? 'change' : 'changes'} couldn’t sync: ${report.rejected.first}. '
            'Edit it to try again — it’s still saved on this phone.';
      } else {
        _state = SyncState.synced;
        _message = report.conflicts > 0
            ? 'Synced. ${report.conflicts} change${report.conflicts == 1 ? ' was' : 's were'} replaced by a newer '
                  'version — review in Settings → Account.'
            : null;
      }
    } on CloudOfflineException {
      _state = SyncState.offline;
      _message = 'Offline — your changes are saved on this phone and will sync when you’re back online.';
      _scheduleRetry();
    } on CloudAuthException {
      _state = SyncState.error;
      _message = 'Please sign in again to keep syncing. Your changes are saved on this phone.';
    } catch (e) {
      _state = SyncState.error;
      _message = 'Sync failed: $e. Your changes are saved on this phone.';
      _scheduleRetry();
    }
    await refreshCounts();
  }

  void _scheduleRetry() {
    if (_disposed || retryDelays.isEmpty) return;
    final delay = retryDelays[_retryIndex.clamp(0, retryDelays.length - 1)];
    _retryIndex++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => syncNow());
  }

  /// Re-applies the version that lost a conflict as a fresh local edit.
  Future<void> restoreConflict(SyncConflict conflict) async {
    final json = conflict.discardedJson;
    switch (conflict.entity) {
      case SyncEntity.meal:
        json == null ? await store.deleteMeal(conflict.entityId) : await store.upsertMeal(Meal.fromJson(json));
      case SyncEntity.savedFood:
        json == null
            ? await store.deleteSavedFood(conflict.entityId)
            : await store.addSavedFood(SavedFood.fromJson(json));
      case SyncEntity.scanFeedback:
        if (json != null) await store.addFeedback(ScanFeedback.fromJson(json));
      case SyncEntity.profile:
        final profile = (json?['profile'] as Map?)?.cast<String, Object?>();
        profile == null ? await store.clearProfile() : await store.saveProfile(UserProfile.fromJson(profile));
        final settings = (json?['settings'] as Map?)?.cast<String, Object?>();
        if (settings != null) await store.saveSettings(AppSettings.fromJson(settings));
    }
    await store.removeConflict(conflict.id);
    await onPulled();
    await refreshCounts();
    scheduleSync();
  }

  Future<void> dismissConflict(SyncConflict conflict) async {
    await store.removeConflict(conflict.id);
    await refreshCounts();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
