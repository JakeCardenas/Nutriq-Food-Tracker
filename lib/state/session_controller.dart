import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app/session.dart';
import '../data/local_data_importer.dart';
import '../data/local_store.dart';
import '../services/auth/auth_service.dart';
import '../services/photo_service.dart';

/// Decides which [AppSession] is active and switches safely between
/// local-only mode and signed-in accounts.
///
/// - Each account uses its own local file, so signing out or switching never
///   shows another account's meals.
/// - After sign-in, local-only data is *offered* for import (never uploaded
///   silently); declining is remembered per account.
/// - Sign-in methods that appear on an account without being linked in the app
///   (Supabase links verified emails automatically) are announced.
class SessionController extends ChangeNotifier {
  SessionController({
    required this.auth,
    required this.buildSession,
    required this.openLocalStore,
    required this.localPhotos,
  });

  final AuthService auth;
  final Future<AppSession> Function(AuthUser? user) buildSession;

  /// Opens the local-only file (used to read it for import while signed in).
  final Future<LocalStore> Function() openLocalStore;
  final PhotoService localPhotos;

  AppSession? _session;
  ImportSummary? _importOffer;
  String? _linkNotice;
  String? _error;
  bool _passwordRecovery = false;
  bool _consentNextImport = false;
  final Set<String> _linkedInApp = {};
  StreamSubscription<AuthEvent>? _sub;
  Future<void> _queue = Future.value();
  bool _disposed = false;

  AppSession? get session => _session;
  ImportSummary? get importOffer => _importOffer;
  String? get linkNotice => _linkNotice;
  String? get error => _error;
  bool get passwordRecovery => _passwordRecovery;

  /// A one-time message for the next screen (e.g. after data was deleted and
  /// the session restarted). Read it with [takeNotice].
  String? get notice => _notice;
  String? _notice;

  String? takeNotice() {
    final n = _notice;
    _notice = null;
    return n;
  }

  void announce(String message) {
    _notice = message;
    _notify();
  }

  Future<void> start() {
    _sub = auth.events.listen(_onAuthEvent);
    return _enqueue(() async {
      await _switchTo(auth.currentUser);
      // Still signed in from last time: catch up with changes from other devices.
      unawaited(_session?.sync?.syncNow());
    });
  }

  /// Completes when queued session switches have finished.
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await _queue;
  }

  Future<void> _enqueue(Future<void> Function() step) => _queue = _queue.then((_) => step()).catchError((Object e) {
    _error = 'Couldn’t open your data: $e';
    _notify();
  });

  void _onAuthEvent(AuthEvent event) {
    switch (event.type) {
      case AuthEventType.signedIn:
        final user = event.user!;
        _enqueue(() async {
          if (_session?.user?.id == user.id) {
            await _checkLinkedProviders(user);
            return;
          }
          final consented = _consentNextImport;
          _consentNextImport = false;
          await _switchTo(user);
          await _afterSignIn(user, importConsented: consented);
        });
      case AuthEventType.signedOut:
        _enqueue(() async {
          if (_session?.isAccount ?? false) await _switchTo(null);
        });
      case AuthEventType.userUpdated:
        final user = event.user;
        if (user != null) {
          _enqueue(() async {
            await _checkLinkedProviders(user);
            _notify();
          });
        }
      case AuthEventType.passwordRecovery:
        // The reset link signs the person in; switch to their account, then ask for a new password.
        _passwordRecovery = true;
        _notify();
        final user = event.user;
        if (user != null && _session?.user?.id != user.id) {
          _enqueue(() async {
            await _switchTo(user);
            await _afterSignIn(user, importConsented: false);
          });
        }
    }
  }

  Future<void> _switchTo(AuthUser? user) async {
    final previous = _session;
    _session = null;
    _importOffer = null;
    _notify();
    await previous?.dispose();
    _session = await buildSession(user);
    _error = null;
    _notify();
  }

  Future<void> _afterSignIn(AuthUser user, {required bool importConsented}) async {
    await _checkLinkedProviders(user);
    final session = _session!;
    final summary = await localImportSummary();
    if (summary != null) {
      if (importConsented) {
        await _import(session);
      } else if (await session.store.readMeta('import_declined') == null) {
        _importOffer = summary;
      }
    }
    _notify();
    unawaited(session.sync?.syncNow());
  }

  Future<void> _checkLinkedProviders(AuthUser user) async {
    final store = _session?.store;
    if (store == null) return;
    final known = (await store.readMeta('known_providers'))?.split(',').where((p) => p.isNotEmpty).toSet();
    final now = user.providers.toSet();
    if (known != null) {
      final unexpected = now.difference(known).difference(_linkedInApp);
      if (unexpected.isNotEmpty) {
        final names = unexpected.map(_providerName).join(' and ');
        _linkNotice =
            '$names is now a way to sign in to this account. Supabase links sign-in methods that share the same '
            'verified email${user.email == null ? '' : ' (${user.email})'}. If that wasn’t you, sign out and reset your '
            'password.';
        _notify();
      }
    }
    await store.writeMeta('known_providers', now.join(','));
  }

  static String _providerName(String p) => switch (p) {
    'google' => 'Google',
    'apple' => 'Apple',
    'email' => 'Email & password',
    _ => p,
  };

  /// Local-only data that hasn't been imported into the signed-in account.
  Future<ImportSummary?> localImportSummary() async {
    final session = _session;
    if (session == null || !session.isAccount) return null;
    final local = await openLocalStore();
    try {
      final summary = await LocalDataImporter.summarize(local, userId: session.user!.id);
      return summary.isEmpty || summary.alreadyImported ? null : summary;
    } finally {
      await local.close();
    }
  }

  Future<ImportResult> acceptImport() async {
    final session = _session!;
    final result = await _import(session);
    _importOffer = null;
    _notify();
    unawaited(session.sync?.syncNow());
    return result;
  }

  Future<ImportResult> _import(AppSession session) async {
    final local = await openLocalStore();
    try {
      final result = await LocalDataImporter.importInto(
        source: local,
        target: session.store,
        userId: session.user!.id,
        copyPhoto: (path) => session.photos.importFile(localPhotos.resolve(path)),
      );
      await session.reload();
      return result;
    } finally {
      await local.close();
    }
  }

  Future<void> declineImport() async {
    await _session?.store.writeMeta('import_declined', DateTime.now().toIso8601String());
    _importOffer = null;
    _notify();
  }

  /// The next sign-in comes from "Save your progress" in onboarding, where the
  /// person already agreed to bring this phone's data into the new account.
  void expectImportConsent() => _consentNextImport = true;

  void markLinkedInApp(String provider) => _linkedInApp.add(provider);

  void dismissLinkNotice() {
    _linkNotice = null;
    _notify();
  }

  void clearPasswordRecovery() {
    _passwordRecovery = false;
    _notify();
  }

  Future<int> pendingChanges() async => await _session?.store.pendingCount() ?? 0;

  Future<void> signOut() async {
    await auth.signOut();
    await _enqueue(() async {
      if (_session?.isAccount ?? false) await _switchTo(null);
    });
  }

  /// The app came back to the foreground: catch up with other devices and
  /// re-read today's Apple Health numbers (only if the person turned that on).
  Future<void> appResumed() async {
    final session = _session;
    if (session == null) return;
    await Future.wait([?session.sync?.syncNow(), session.health.refresh()]);
  }

  /// Rebuilds the current session (after wiping its data).
  Future<void> restartSession() => _enqueue(() => _switchTo(_session?.user));

  /// Deletes this account's meals, goals and foods from the server, then this
  /// phone's copy. The account and sign-in stay. If the server call fails,
  /// nothing on the phone is touched and the error is rethrown.
  Future<void> deleteCloudData() async {
    final session = _accountSession();
    await session.cloud!.deleteAllMyData();
    await _enqueue(() async {
      await _wipe(session);
      await _switchTo(session.user);
    });
  }

  /// Deletes the account through the server-side `delete-account` function
  /// (which removes all of its rows), then this phone's copy, then signs out.
  /// Throws [CloudNotConfiguredException] when the function isn't deployed.
  Future<void> deleteAccount() async {
    final session = _accountSession();
    await session.cloud!.deleteAccount();
    await _enqueue(() async {
      await _wipe(session);
      await _switchTo(null);
    });
    await _signOutQuietly();
  }

  /// Signs out and removes this account's copy from this phone. Data already
  /// synced stays in the account.
  Future<void> removeAccountFromPhone() async {
    final session = _accountSession();
    await _enqueue(() async {
      await _wipe(session);
      await _switchTo(null);
    });
    await _signOutQuietly();
  }

  /// Local-only mode: deletes everything on this phone and starts over.
  Future<void> deleteLocalData() async {
    final session = _session!;
    await _enqueue(() async {
      await _wipe(session);
      await _switchTo(session.user);
    });
  }

  AppSession _accountSession() {
    final session = _session;
    if (session == null || !session.isAccount || session.cloud == null) {
      throw StateError('Not signed in to an account');
    }
    return session;
  }

  Future<void> _wipe(AppSession session) async {
    await session.store.wipe();
    await session.photos.deleteAll();
  }

  Future<void> _signOutQuietly() async {
    try {
      await auth.signOut();
    } catch (_) {
      // The local session is already gone; a failed server sign-out changes nothing here.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _session?.dispose();
    super.dispose();
  }
}
