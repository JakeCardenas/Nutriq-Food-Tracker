import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/services/food_analysis/photo_estimate_backend.dart';

void main() {
  test('the upload says the person consented and carries only the prepared JPEG', () {
    final jpeg = Uint8List.fromList([0xff, 0xd8, 1, 2]);
    expect(SupabasePhotoEstimateBackend.requestBody(jpeg), {
      'consent': true,
      'mimeType': 'image/jpeg',
      'image': base64Encode(jpeg),
    });
  });

  test('server answers map to what the person is told', () {
    PhotoEstimateFailure f(int status, [Object? details]) =>
        SupabasePhotoEstimateBackend.errorFor(status, details).failure;
    expect(f(0), PhotoEstimateFailure.offline);
    expect(f(401), PhotoEstimateFailure.signedOut);
    expect(f(403, {'error': 'consent_required'}), PhotoEstimateFailure.rejected);
    expect(f(400), PhotoEstimateFailure.rejected);
    expect(f(413), PhotoEstimateFailure.rejected);
    expect(f(404), PhotoEstimateFailure.notSetUp);
    expect(f(503, {'error': 'not_configured'}), PhotoEstimateFailure.notSetUp);
    expect(f(503, {'error': 'provider_quota'}), PhotoEstimateFailure.providerBusy);
    expect(f(504), PhotoEstimateFailure.timeout);
    expect(f(502), PhotoEstimateFailure.failed);
    expect(f(500), PhotoEstimateFailure.failed);
  });

  test('the daily limit carries the limit and reset time', () {
    final e = SupabasePhotoEstimateBackend.errorFor(429, {
      'error': 'daily_limit',
      'limit': 10,
      'resetsAt': '2026-10-08T00:00:00.000Z',
    });
    expect(e.failure, PhotoEstimateFailure.dailyLimit);
    expect(e.limit, 10);
    expect(e.resetsAt, DateTime.utc(2026, 10, 8));
  });
}
