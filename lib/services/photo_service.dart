import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/ids.dart';

enum PhotoSource { camera, library }

enum PhotoFailure { permissionDenied, cameraUnavailable, unknown }

sealed class PhotoPickResult {
  const PhotoPickResult();
}

class PhotoPicked extends PhotoPickResult {
  const PhotoPicked(this.tempPath);
  final String tempPath;
}

class PhotoCancelled extends PhotoPickResult {
  const PhotoCancelled();
}

class PhotoPickFailed extends PhotoPickResult {
  const PhotoPickFailed(this.failure, this.source);
  final PhotoFailure failure;
  final PhotoSource source;
}

/// Picks meal photos and keeps them in app storage. Photos never leave the
/// device in this version.
abstract interface class PhotoService {
  Future<PhotoPickResult> pick(PhotoSource source);

  /// Copies a picked photo into app storage and returns a path *relative* to
  /// the documents folder (iOS changes the absolute container path on updates).
  Future<String> persist(String tempPath);

  File resolve(String storedPath);
  Future<Uint8List> readBytes(String storedPath);
  Future<void> delete(String storedPath);

  /// Removes every photo this service stored (used when deleting data).
  Future<void> deleteAll();

  /// Copies a photo file from another mode (e.g. local-only → account) into this
  /// service's folder and returns the new relative path, or null if it's missing.
  Future<String?> importFile(File source);
}

class DevicePhotoService implements PhotoService {
  DevicePhotoService._(this._documentsDir, this._folder);

  /// Local-only mode keeps photos in `meal_photos/`; each signed-in account gets
  /// `accounts/<user-id>/meal_photos/` so accounts never share photo files.
  final String _folder;
  final String _documentsDir;
  final _picker = ImagePicker();

  static Future<DevicePhotoService> create({String? userId}) async => DevicePhotoService._(
    (await getApplicationDocumentsDirectory()).path,
    userId == null ? 'meal_photos' : p.join('accounts', userId, 'meal_photos'),
  );

  @override
  Future<void> deleteAll() async {
    final dir = Directory(p.join(_documentsDir, _folder));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  @override
  Future<PhotoPickResult> pick(PhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      return file == null ? const PhotoCancelled() : PhotoPicked(file.path);
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();
      if (code.contains('access_denied') || code.contains('permission')) {
        return PhotoPickFailed(PhotoFailure.permissionDenied, source);
      }
      if (code.contains('no_available_camera') || code.contains('camera_unavailable')) {
        return PhotoPickFailed(PhotoFailure.cameraUnavailable, source);
      }
      return PhotoPickFailed(PhotoFailure.unknown, source);
    } catch (_) {
      return PhotoPickFailed(PhotoFailure.unknown, source);
    }
  }

  @override
  Future<String> persist(String tempPath) async {
    final dir = Directory(p.join(_documentsDir, _folder));
    await dir.create(recursive: true);
    final ext = p.extension(tempPath).isEmpty ? '.jpg' : p.extension(tempPath);
    final relative = p.join(_folder, '${newId()}$ext');
    await File(tempPath).copy(p.join(_documentsDir, relative));
    return relative;
  }

  @override
  File resolve(String storedPath) => File(p.isAbsolute(storedPath) ? storedPath : p.join(_documentsDir, storedPath));

  @override
  Future<Uint8List> readBytes(String storedPath) => resolve(storedPath).readAsBytes();

  @override
  Future<void> delete(String storedPath) async {
    final file = resolve(storedPath);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<String?> importFile(File source) async {
    if (!await source.exists()) return null;
    return persist(source.path);
  }
}
