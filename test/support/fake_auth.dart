import 'dart:async';

import 'package:nutriq/services/auth/auth_service.dart';

/// Scriptable [AuthService]: sign-ins succeed immediately and emit events,
/// like Supabase does.
class FakeAuthService implements AuthService {
  FakeAuthService({this.current, this.supportsApple = false, this.supportsGoogle = false});

  AuthUser? current;
  final _events = StreamController<AuthEvent>.broadcast();
  AuthFailure? nextFailure;
  bool needsConfirmation = false;
  final resetEmails = <String>[];

  @override
  bool get isConfigured => true;
  @override
  final bool supportsApple;
  @override
  final bool supportsGoogle;
  @override
  AuthUser? get currentUser => current;
  @override
  Stream<AuthEvent> get events => _events.stream;

  void emit(AuthEvent e) => _events.add(e);

  AuthUser signIn(AuthUser user) {
    current = user;
    _events.add(AuthEvent(AuthEventType.signedIn, user));
    return user;
  }

  void _maybeFail() {
    final f = nextFailure;
    if (f != null) {
      nextFailure = null;
      throw f;
    }
  }

  @override
  Future<SignUpResult> signUpWithEmail(String email, String password) async {
    _maybeFail();
    final user = AuthUser(id: 'user-$email', email: email, providers: const ['email']);
    if (needsConfirmation) return SignUpResult(needsEmailConfirmation: true, user: user);
    return SignUpResult(needsEmailConfirmation: false, user: signIn(user));
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    _maybeFail();
    return signIn(AuthUser(id: 'user-$email', email: email, providers: const ['email']));
  }

  @override
  Future<void> resendConfirmation(String email) async => _maybeFail();
  @override
  Future<void> sendPasswordReset(String email) async {
    _maybeFail();
    resetEmails.add(email);
  }

  @override
  Future<void> updatePassword(String newPassword) async => _maybeFail();
  @override
  Future<AuthUser?> signInWithGoogle() async {
    _maybeFail();
    return signIn(const AuthUser(id: 'google-user', email: 'g@example.com', providers: ['google']));
  }

  @override
  Future<AuthUser?> signInWithApple() async {
    _maybeFail();
    return signIn(const AuthUser(id: 'apple-user', providers: ['apple']));
  }

  @override
  Future<bool> linkGoogle() async => true;
  @override
  Future<bool> linkApple() async => true;

  @override
  Future<void> signOut() async {
    current = null;
    _events.add(const AuthEvent(AuthEventType.signedOut));
  }
}
