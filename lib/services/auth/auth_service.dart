import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Who is signed in. [id] is the Supabase Auth user id — the owner of every
/// cloud row and the key of this account's local file.
class AuthUser {
  const AuthUser({required this.id, this.email, this.displayName, this.providers = const []});
  final String id;
  final String? email;
  final String? displayName;

  /// Linked sign-in methods, e.g. ['email', 'google', 'apple'].
  final List<String> providers;
}

enum AuthEventType { signedIn, signedOut, passwordRecovery, userUpdated }

class AuthEvent {
  const AuthEvent(this.type, [this.user]);
  final AuthEventType type;
  final AuthUser? user;
}

class SignUpResult {
  const SignUpResult({required this.needsEmailConfirmation, this.user});
  final bool needsEmailConfirmation;
  final AuthUser? user;
}

/// A user-presentable auth error.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

/// Sign-in and account management. The Supabase implementation lives in
/// `supabase_auth_service.dart`; [DisabledAuthService] is used when no cloud
/// configuration was supplied, so the app runs in local-only mode.
abstract interface class AuthService {
  bool get isConfigured;
  bool get supportsApple;
  bool get supportsGoogle;
  AuthUser? get currentUser;
  Stream<AuthEvent> get events;

  Future<SignUpResult> signUpWithEmail(String email, String password);
  Future<AuthUser> signInWithEmail(String email, String password);
  Future<void> resendConfirmation(String email);
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String newPassword);

  /// Returns null when the person cancelled.
  Future<AuthUser?> signInWithGoogle();
  Future<AuthUser?> signInWithApple();

  /// Explicitly links another method to the signed-in account (no silent merges).
  Future<bool> linkGoogle();
  Future<bool> linkApple();

  Future<void> signOut();
}

class DisabledAuthService implements AuthService {
  const DisabledAuthService();
  static const _failure = AuthFailure('Cloud accounts aren’t set up in this build. Nutriq works fully on this phone.');

  @override
  bool get isConfigured => false;
  @override
  bool get supportsApple => false;
  @override
  bool get supportsGoogle => false;
  @override
  AuthUser? get currentUser => null;
  @override
  Stream<AuthEvent> get events => const Stream.empty();
  @override
  Future<SignUpResult> signUpWithEmail(String email, String password) => throw _failure;
  @override
  Future<AuthUser> signInWithEmail(String email, String password) => throw _failure;
  @override
  Future<void> resendConfirmation(String email) => throw _failure;
  @override
  Future<void> sendPasswordReset(String email) => throw _failure;
  @override
  Future<void> updatePassword(String newPassword) => throw _failure;
  @override
  Future<AuthUser?> signInWithGoogle() => throw _failure;
  @override
  Future<AuthUser?> signInWithApple() => throw _failure;
  @override
  Future<bool> linkGoogle() => throw _failure;
  @override
  Future<bool> linkApple() => throw _failure;
  @override
  Future<void> signOut() async {}
}

/// Which sign-in buttons a build can show.
abstract final class AuthProviders {
  /// Native Sign in with Apple only — no Android browser OAuth in this version.
  static bool appleVisible({required TargetPlatform platform, required bool enabled}) =>
      enabled && platform == TargetPlatform.iOS;

  static bool googleVisible({
    required TargetPlatform platform,
    required String webClientId,
    required String iosClientId,
  }) {
    if (webClientId.isEmpty) return false;
    return switch (platform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => iosClientId.isNotEmpty,
      _ => false,
    };
  }
}

/// Apple ID-token nonce: Apple receives the SHA-256 hash, Supabase receives
/// the raw value and checks that it hashes to the token's `nonce` claim.
class AppleNonce {
  const AppleNonce._(this.raw, this.hashed);
  final String raw;
  final String hashed;

  static AppleNonce generate([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    final raw = List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
    return AppleNonce._(raw, sha256.convert(utf8.encode(raw)).toString());
  }
}

/// Apple shares the name only on the very first authorization. Save it then,
/// and never overwrite a name the account already has.
String? appleNameToSave({required String? givenName, required String? familyName, required String? existing}) {
  if (existing != null && existing.trim().isNotEmpty) return null;
  final name = [givenName, familyName].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).join(' ');
  return name.isEmpty ? null : name;
}

/// With email confirmation on, Supabase answers a sign-up for an existing,
/// confirmed address with a placeholder user that has no identities.
bool looksLikeExistingAccount({required int identityCount}) => identityCount == 0;

/// Plain-language messages for Supabase Auth error codes.
String describeAuthError(String? code, String message) {
  final lower = message.toLowerCase();
  if (code == null && (lower.contains('network') || lower.contains('socket') || lower.contains('failed host'))) {
    return 'No connection. Check your internet and try again.';
  }
  return switch (code) {
    'invalid_credentials' => 'Email or password is incorrect.',
    'email_not_confirmed' => 'Please confirm your email first — check your inbox (and spam) for the link.',
    'user_already_exists' => 'An account with this email already exists. Try signing in instead.',
    'email_exists' =>
      'This email already has a Nutriq account with a different sign-in method. Please sign in that way, '
          'then link this method in Settings → Account.',
    'identity_already_exists' =>
      'That sign-in method is already linked to another Nutriq account. Sign in with it there, or unlink it first '
          '(Settings → Account).',
    'weak_password' => 'Choose a stronger password — at least 8 characters.',
    'same_password' => 'Your new password must be different from the old one.',
    'over_email_send_rate_limit' ||
    'over_request_rate_limit' => 'Too many attempts. Please wait a minute and try again.',
    'provider_disabled' => 'This sign-in method isn’t enabled for Nutriq yet.',
    'otp_expired' || 'flow_state_expired' => 'That link has expired. Request a new one.',
    'session_not_found' || 'refresh_token_not_found' => 'Your session expired. Please sign in again.',
    'validation_failed' => 'Please check the email address.',
    _ => message,
  };
}
