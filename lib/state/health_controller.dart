import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../domain/models/meal.dart';
import '../services/health/health_service.dart';

enum HealthStatus { unsupported, off, connecting, connected, error }

/// Optional Apple Health connection. Nothing is requested until the person
/// turns it on in Settings. Reading and writing are separate opt-ins; data
/// read from Apple Health stays on this phone and is never uploaded.
class HealthController extends ChangeNotifier {
  HealthController({required this.service, required this.store});

  final HealthService service;
  final LocalStore store;

  static const _readKey = 'health:read';
  static const _writeKey = 'health:write';

  HealthStatus _status = HealthStatus.off;
  bool _writeEnabled = false;
  HealthSnapshot? _today;
  String? _message;
  DateTime? _lastRead;
  bool _disposed = false;

  HealthStatus get status => _status;
  bool get writeEnabled => _writeEnabled;
  HealthSnapshot? get today => _today;
  String? get message => _message;
  DateTime? get lastRead => _lastRead;
  bool get isConnected => _status == HealthStatus.connected;

  Future<bool> _supported() async =>
      service.platformSupported && await service.availability() == HealthAvailability.available;

  Future<void> load() async {
    if (!await _supported()) {
      _set(HealthStatus.unsupported);
      return;
    }
    final on = await store.readMeta(_readKey) == '1';
    _writeEnabled = on && await store.readMeta(_writeKey) == '1';
    if (on) {
      _status = HealthStatus.connected;
      await refresh();
    } else {
      _set(HealthStatus.off);
    }
  }

  Future<void> connect() async {
    if (!await _supported()) {
      _set(HealthStatus.unsupported, 'Apple Health isn’t available on this device.');
      return;
    }
    _set(HealthStatus.connecting);
    try {
      await service.requestReadAccess();
      await store.writeMeta(_readKey, '1');
      _status = HealthStatus.connected;
      await refresh();
    } catch (e) {
      _set(HealthStatus.error, 'Couldn’t connect to Apple Health: $e');
    }
  }

  Future<void> refresh() async {
    if (_status != HealthStatus.connected) return;
    final now = DateTime.now();
    try {
      _today = await service.readDay(DateTime(now.year, now.month, now.day), now);
      _lastRead = now;
      _message = _today!.isEmpty
          ? 'No Apple Health data found for today yet. If you expected some, check Settings → Health → '
                'Data Access & Devices → Nutriq and make sure the data types are turned on.'
          : null;
    } catch (e) {
      _message = 'Couldn’t read Apple Health right now: $e';
    }
    _notify();
  }

  Future<void> setWriteEnabled(bool enabled) async {
    if (!enabled) {
      _writeEnabled = false;
      await store.writeMeta(_writeKey, null);
      _notify();
      return;
    }
    if (_status != HealthStatus.connected) return;
    try {
      await service.requestWriteAccess();
      _writeEnabled = true;
      await store.writeMeta(_writeKey, '1');
      _message = null;
    } catch (e) {
      _writeEnabled = false;
      _message = 'Couldn’t turn on writing to Apple Health: $e';
    }
    _notify();
  }

  /// Turns the connection off on this phone. (Apple Health permissions themselves
  /// can only be revoked by the person in the Health app.)
  Future<void> disconnect() async {
    await store.writeMeta(_readKey, null);
    await store.writeMeta(_writeKey, null);
    _writeEnabled = false;
    _today = null;
    _lastRead = null;
    _set(HealthStatus.off);
  }

  /// Writes a newly logged meal's nutrition to Apple Health exactly once.
  /// Nutriq never reads nutrition back, so this can't create a sync loop.
  Future<void> onMealSaved(Meal meal) async {
    if (!_writeEnabled || _status != HealthStatus.connected) return;
    if (await store.wasWrittenToHealth(meal.id)) return;
    try {
      if (await service.writeMeal(meal)) await store.recordHealthWrite(meal.id);
    } catch (e) {
      _message = 'Couldn’t write “${meal.title}” to Apple Health: $e';
      _notify();
    }
  }

  void _set(HealthStatus status, [String? message]) {
    _status = status;
    _message = message;
    _notify();
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
