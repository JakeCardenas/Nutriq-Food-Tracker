import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/data/cloud_repository.dart';
import 'package:nutriq/data/supabase_cloud_repository.dart';

void main() {
  test('an expired sign-in asks the person to sign in again', () {
    expect(SupabaseCloudRepository.deleteAccountError(401), isA<CloudAuthException>());
    expect(SupabaseCloudRepository.deleteAccountError(403), isA<CloudAuthException>());
  });

  test('a missing function says it isn’t deployed', () {
    expect(SupabaseCloudRepository.deleteAccountError(404), isA<CloudNotConfiguredException>());
  });

  test('other failures are reported as rejected', () {
    expect(SupabaseCloudRepository.deleteAccountError(500), isA<CloudRejectedException>());
  });
}
