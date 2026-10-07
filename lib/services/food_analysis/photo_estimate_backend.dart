import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Sends a prepared (resized, metadata-free) JPEG to Nutriq's `scan-photo`
/// server function, which asks Gemini for candidate foods and looks up
/// nutrition. Only used after the person opted in. Fails with a
/// [PhotoEstimateException].
abstract interface class PhotoEstimateBackend {
  Future<Map<String, Object?>> estimate(Uint8List jpeg);
}

enum PhotoEstimateFailure { offline, signedOut, notSetUp, dailyLimit, providerBusy, timeout, rejected, failed }

class PhotoEstimateException implements Exception {
  const PhotoEstimateException(this.failure, {this.limit, this.resetsAt});
  final PhotoEstimateFailure failure;

  /// For [PhotoEstimateFailure.dailyLimit].
  final int? limit;
  final DateTime? resetsAt;

  @override
  String toString() => 'PhotoEstimateException($failure)';
}

class SupabasePhotoEstimateBackend implements PhotoEstimateBackend {
  SupabasePhotoEstimateBackend(this._client);

  final SupabaseClient _client;
  static const timeout = Duration(seconds: 40);

  @override
  Future<Map<String, Object?>> estimate(Uint8List jpeg) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke('scan-photo', body: requestBody(jpeg)).timeout(timeout);
    } on FunctionException catch (e) {
      throw errorFor(e.status, e.details);
    } on TimeoutException {
      throw const PhotoEstimateException(PhotoEstimateFailure.timeout);
    } catch (_) {
      throw const PhotoEstimateException(PhotoEstimateFailure.offline);
    }
    final data = response.data;
    if (data is! Map) throw const PhotoEstimateException(PhotoEstimateFailure.failed);
    return data.cast<String, Object?>();
  }

  /// The upload: consent flag plus the prepared JPEG — nothing else about the person or the photo.
  static Map<String, Object?> requestBody(Uint8List jpeg) => {
    'consent': true,
    'mimeType': 'image/jpeg',
    'image': base64Encode(jpeg),
  };

  /// What a failed call means for the person. Status 0 = no response at all.
  static PhotoEstimateException errorFor(int status, Object? details) {
    final body = details is Map ? details : null;
    final error = body?['error'];
    return switch (status) {
      0 => const PhotoEstimateException(PhotoEstimateFailure.offline),
      401 => const PhotoEstimateException(PhotoEstimateFailure.signedOut),
      400 || 403 || 413 => const PhotoEstimateException(PhotoEstimateFailure.rejected),
      404 => const PhotoEstimateException(PhotoEstimateFailure.notSetUp),
      429 => PhotoEstimateException(
        PhotoEstimateFailure.dailyLimit,
        limit: (body?['limit'] as num?)?.toInt(),
        resetsAt: body?['resetsAt'] is String ? DateTime.tryParse(body!['resetsAt'] as String) : null,
      ),
      503 when error == 'provider_quota' => const PhotoEstimateException(PhotoEstimateFailure.providerBusy),
      503 => const PhotoEstimateException(PhotoEstimateFailure.notSetUp),
      504 => const PhotoEstimateException(PhotoEstimateFailure.timeout),
      _ => const PhotoEstimateException(PhotoEstimateFailure.failed),
    };
  }
}
