import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nutriq/services/food_analysis/photo_upload.dart';

/// A phone-style JPEG: large, stored sideways with an orientation flag, and
/// carrying camera EXIF data.
Uint8List _cameraPhoto({int width = 3000, int height = 2000, int orientation = 6}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 120, 40));
  image.exif.imageIfd.orientation = orientation;
  image.exif.imageIfd['Make'] = img.IfdValueAscii('NutriqTestCam');
  return img.encodeJpg(image, quality: 95);
}

bool _contains(Uint8List bytes, String text) => latin1.decode(bytes).contains(text);

void main() {
  test('the test photo really has EXIF and a sideways orientation', () {
    final input = _cameraPhoto();
    expect(_contains(input, 'Exif'), isTrue);
    expect(_contains(input, 'NutriqTestCam'), isTrue);
  });

  test('resizes to at most 1024 px, upright, as a JPEG with no metadata', () {
    final out = preparePhotoSync(_cameraPhoto());
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, 683, reason: '3000×2000 shown sideways is 2000×3000 → 683×1024');
    expect(decoded.height, 1024);
    expect(_contains(out, 'Exif'), isFalse);
    expect(_contains(out, 'NutriqTestCam'), isFalse);
    expect(_contains(out, 'http://ns.adobe.com/xap'), isFalse);
    expect(out.length, lessThanOrEqualTo(maxUploadBytes));
  });

  test('small photos are not enlarged', () {
    final decoded = img.decodeJpg(preparePhotoSync(_cameraPhoto(width: 400, height: 300, orientation: 1)))!;
    expect(decoded.width, 400);
    expect(decoded.height, 300);
  });

  test('something that isn’t a picture is refused', () {
    expect(() => preparePhotoSync(Uint8List.fromList(utf8.encode('not a photo'))), throwsA(isA<PhotoPrepException>()));
  });

  test('runs off the UI thread with the same result', () async {
    final out = await preparePhotoForUpload(_cameraPhoto(orientation: 1));
    expect(img.decodeJpg(out)!.width, 1024);
  });
}
