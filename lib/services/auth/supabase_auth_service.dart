import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../app/env.dart';
import 'auth_service.dart';

/// Supabase Auth with email/password, native Google (ID token) and native
/// Sign in with Apple on iOS (ID token + SHA-256 nonce).
///
/// Email confirmation and password-reset links return to the app through the
/// `com.prodbyjake.nutriq://login-callback` deep link; supabase_flutter
/// exchanges the PKCE code and emits the matching auth event.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client) {
    _sub = _client.auth.onAuthStateChange.listen((state) {
      final user = _toUser(state.session?.user);
      switch (state.event) {
        case sb.AuthChangeEvent.signedIn:
          if (user != null) _events.add(AuthEvent(AuthEventType.signedIn, user));
        case sb.AuthChangeEvent.signedOut:
          _events.add(const AuthEvent(AuthEventType.signedOut));
        case sb.AuthChangeEvent.passwordRecovery:
          _events.add(AuthEvent(AuthEventType.passwordRecovery, user));
        case sb.AuthChangeEvent.userUpdated:
          _events.add(AuthEvent(AuthEventType.userUpdated, user));
        default:
          break;
      }
    });
  }

  final sb.SupabaseClient _client;
  final _events = StreamController<AuthEvent>.broadcast();
  StreamSubscription<sb.AuthState>? _sub;
  Future<void>? _googleInit;

  @override
  bool get isConfigured => true;

  @override
  bool get supportsApple =>
      AuthProviders.appleVisible(platform: defaultTargetPlatform, enabled: Env.appleSignInEnabled);

  @override
  bool get supportsGoogle => AuthProviders.googleVisible(
    platform: defaultTargetPlatform,
    webClientId: Env.googleWebClientId,
    iosClientId: Env.googleIosClientId,
  );

  @override
  AuthUser? get currentUser => _toUser(_client.auth.currentUser);

  @override
  Stream<AuthEvent> get events => _events.stream;

  // ── email ──────────────────────────────────────────────────────────────

  @override
  Future<SignUpResult> signUpWithEmail(String email, String password) => _guard(() async {
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: Env.authRedirectUrl,
    );
    final user = res.user;
    if (user != null && looksLikeExistingAccount(identityCount: user.identities?.length ?? 0)) {
      throw const AuthFailure(
        'An account with this email may already exist. Try signing in, or reset your password.',
        code: 'user_already_exists',
      );
    }
    return SignUpResult(needsEmailConfirmation: res.session == null, user: _toUser(user));
  });

  @override
  Future<AuthUser> signInWithEmail(String email, String password) => _guard(() async {
    final res = await _client.auth.signInWithPassword(email: email.trim(), password: password);
    return _toUser(res.user)!;
  });

  @override
  Future<void> resendConfirmation(String email) => _guard(
    () => _client.auth.resend(type: sb.OtpType.signup, email: email.trim(), emailRedirectTo: Env.authRedirectUrl),
  );

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _client.auth.resetPasswordForEmail(email.trim(), redirectTo: Env.authRedirectUrl));

  @override
  Future<void> updatePassword(String newPassword) =>
      _guard(() => _client.auth.updateUser(sb.UserAttributes(password: newPassword)));

  // ── Google (native, ID token) ──────────────────────────────────────────

  Future<void> _ensureGoogle() => _googleInit ??= GoogleSignIn.instance.initialize(
    clientId: Platform.isIOS ? Env.googleIosClientId : null,
    serverClientId: Env.googleWebClientId,
  );

  Future<({String idToken, String? accessToken})?> _googleTokens() async {
    await _ensureGoogle();
    try {
      final account = await GoogleSignIn.instance.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthFailure('Google didn’t return an ID token. Check the Google client IDs in config/nutriq.json.');
      }
      final authorization = await account.authorizationClient.authorizationForScopes(const ['email']);
      return (idToken: idToken, accessToken: authorization?.accessToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthFailure('Google sign-in failed: ${e.description ?? e.code.name}');
    }
  }

  @override
  Future<AuthUser?> signInWithGoogle() => _guard(() async {
    final tokens = await _googleTokens();
    if (tokens == null) return null;
    final res = await _client.auth.signInWithIdToken(
      provider: sb.OAuthProvider.google,
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
    );
    return _toUser(res.user);
  });

  @override
  Future<bool> linkGoogle() => _guard(() async {
    final tokens = await _googleTokens();
    if (tokens == null) return false;
    await _client.auth.linkIdentityWithIdToken(
      provider: sb.OAuthProvider.google,
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
    );
    return true;
  });

  // ── Apple (native iOS, ID token + nonce) ───────────────────────────────

  Future<({String idToken, String rawNonce, String? givenName, String? familyName})?> _appleTokens() async {
    if (!supportsApple) throw const AuthFailure('Sign in with Apple is available on iPhone only.');
    final nonce = AppleNonce.generate();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: nonce.hashed,
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthFailure('Apple didn’t return an identity token. Please try again.');
      }
      return (
        idToken: idToken,
        rawNonce: nonce.raw,
        givenName: credential.givenName,
        familyName: credential.familyName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw AuthFailure('Sign in with Apple failed: ${e.message}');
    }
  }

  @override
  Future<AuthUser?> signInWithApple() => _guard(() async {
    final tokens = await _appleTokens();
    if (tokens == null) return null;
    final res = await _client.auth.signInWithIdToken(
      provider: sb.OAuthProvider.apple,
      idToken: tokens.idToken,
      nonce: tokens.rawNonce,
    );
    final name = appleNameToSave(
      givenName: tokens.givenName,
      familyName: tokens.familyName,
      existing: res.user?.userMetadata?['full_name'] as String?,
    );
    if (name != null) {
      await _client.auth.updateUser(
        sb.UserAttributes(data: {'full_name': name, 'given_name': tokens.givenName, 'family_name': tokens.familyName}),
      );
    }
    return currentUser;
  });

  @override
  Future<bool> linkApple() => _guard(() async {
    final tokens = await _appleTokens();
    if (tokens == null) return false;
    await _client.auth.linkIdentityWithIdToken(
      provider: sb.OAuthProvider.apple,
      idToken: tokens.idToken,
      nonce: tokens.rawNonce,
    );
    return true;
  });

  @override
  Future<void> signOut() => _guard(() async {
    await _client.auth.signOut();
    if (_googleInit != null) await GoogleSignIn.instance.signOut();
  });

  // ── helpers ────────────────────────────────────────────────────────────

  static AuthUser? _toUser(sb.User? u) {
    if (u == null) return null;
    final meta = u.userMetadata ?? const {};
    return AuthUser(
      id: u.id,
      email: u.email,
      displayName: (meta['full_name'] ?? meta['name']) as String?,
      providers: [for (final i in u.identities ?? const <sb.UserIdentity>[]) i.provider],
    );
  }

  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AuthFailure {
      rethrow;
    } on sb.AuthRetryableFetchException {
      throw const AuthFailure('No connection. Check your internet and try again.');
    } on sb.AuthException catch (e) {
      throw AuthFailure(describeAuthError(e.code, e.message), code: e.code);
    } on SocketException {
      throw const AuthFailure('No connection. Check your internet and try again.');
    }
  }

  void dispose() {
    _sub?.cancel();
    _events.close();
  }
}
