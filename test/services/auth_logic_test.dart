import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/services/auth/auth_service.dart';

void main() {
  group('friendly auth errors', () {
    test('known codes get plain-language messages', () {
      expect(describeAuthError('invalid_credentials', 'x'), contains('incorrect'));
      expect(describeAuthError('email_not_confirmed', 'x'), contains('confirm'));
      expect(describeAuthError('user_already_exists', 'x'), contains('already'));
      expect(describeAuthError('weak_password', 'x'), contains('8'));
      expect(describeAuthError('over_email_send_rate_limit', 'x'), contains('wait'));
      expect(describeAuthError('identity_already_exists', 'x'), contains('Settings'));
      expect(describeAuthError(null, 'Network request failed'), contains('connection'));
    });

    test('an email used by another sign-in method explains how to link instead of merging', () {
      final message = describeAuthError('email_exists', 'x');
      expect(message, contains('sign in'));
      expect(message, contains('link'));
    });

    test('unknown errors fall back to the server message', () {
      expect(describeAuthError('something_new', 'Server said no'), 'Server said no');
    });
  });

  group('provider visibility', () {
    test('Apple is iOS-only and needs the paid-team capability flag', () {
      expect(AuthProviders.appleVisible(platform: TargetPlatform.iOS, enabled: true), isTrue);
      expect(AuthProviders.appleVisible(platform: TargetPlatform.iOS, enabled: false), isFalse);
      expect(AuthProviders.appleVisible(platform: TargetPlatform.android, enabled: true), isFalse);
    });

    test('Google needs the web client id, plus the iOS client id on iPhone', () {
      expect(AuthProviders.googleVisible(platform: TargetPlatform.android, webClientId: 'w', iosClientId: ''), isTrue);
      expect(AuthProviders.googleVisible(platform: TargetPlatform.iOS, webClientId: 'w', iosClientId: ''), isFalse);
      expect(AuthProviders.googleVisible(platform: TargetPlatform.iOS, webClientId: 'w', iosClientId: 'i'), isTrue);
      expect(AuthProviders.googleVisible(platform: TargetPlatform.android, webClientId: '', iosClientId: 'i'), isFalse);
    });
  });

  test('Apple nonce: the hash goes to Apple, the raw value to Supabase', () {
    final nonce = AppleNonce.generate();
    expect(nonce.raw.length, 32);
    expect(nonce.hashed, sha256.convert(utf8.encode(nonce.raw)).toString());
    expect(AppleNonce.generate().raw, isNot(nonce.raw));
  });

  test('Apple name is saved only when Apple provides it and none is stored', () {
    expect(appleNameToSave(givenName: 'Ada', familyName: 'Lovelace', existing: null), 'Ada Lovelace');
    expect(appleNameToSave(givenName: null, familyName: null, existing: null), isNull);
    expect(appleNameToSave(givenName: 'Ada', familyName: null, existing: 'Ada L.'), isNull);
    expect(appleNameToSave(givenName: '  ', familyName: '', existing: null), isNull);
  });

  test('a sign-up for an existing confirmed email is recognised', () {
    expect(looksLikeExistingAccount(identityCount: 0), isTrue);
    expect(looksLikeExistingAccount(identityCount: 1), isFalse);
  });
}
