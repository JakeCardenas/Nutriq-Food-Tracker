import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Longest side of an uploaded photo, in pixels. Enough to recognise food.
const maxUploadSide = 1024;

/// Uploads larger than this are re-encoded at lower quality (the server refuses > 1.5 MB).
const maxUploadBytes = 900 * 1024;

class PhotoPrepException implements Exception {
  const PhotoPrepException(this.message);
  final String message;

  @override
  String toString() => 'PhotoPrepException: $message';
}

/// Makes the copy of a meal photo that may be uploaded — only after the
/// person agreed: turned upright, shrunk to [maxUploadSide], and re-encoded
/// from pixels as a JPEG so no EXIF/GPS, camera or other metadata goes with it.
/// The original photo on the phone is untouched. Runs in a background isolate.
Future<Uint8List> preparePhotoForUpload(Uint8List original) => Isolate.run(() => preparePhotoSync(original));

Uint8List preparePhotoSync(Uint8List original) {
  final decoded = img.decodeImage(original);
  if (decoded == null) throw const PhotoPrepException('not a supported image');
  final upright = img.bakeOrientation(decoded);
  final longest = upright.width > upright.height ? upright.width : upright.height;
  final sized = longest <= maxUploadSide
      ? upright
      : img.copyResize(
          upright,
          width: upright.width >= upright.height ? maxUploadSide : null,
          height: upright.height > upright.width ? maxUploadSide : null,
          interpolation: img.Interpolation.average,
        );
  // Drop every piece of metadata before encoding.
  sized.exif = img.ExifData();
  sized.iccProfile = null;
  sized.textData = null;
  for (final quality in const [82, 72, 60, 50]) {
    final jpeg = img.encodeJpg(sized, quality: quality);
    if (jpeg.length <= maxUploadBytes) return jpeg;
  }
  throw const PhotoPrepException('photo is too large to upload');
}
