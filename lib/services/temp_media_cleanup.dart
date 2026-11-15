import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Removes stale raw camera captures and their derived photo-watermark copies.
///
/// Normal captures clean up after themselves. This sweep catches only files
/// whose names match the camera plugin's capture prefixes (CAP/REC), plus
/// photo watermark copies derived from CAP JPEGs. Unrelated cache images/videos
/// are deliberately left untouched.
class TempMediaCleanup {
  TempMediaCleanup({
    Future<Directory> Function()? temporaryDirectory,
    DateTime Function()? clock,
    this.minAge = const Duration(hours: 6),
  })  : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
        _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _temporaryDirectory;
  final DateTime Function() _clock;
  final Duration minAge;

  static final RegExp _cameraPhoto =
      RegExp(r'^CAP[^/\\]*\.(?:JPG|JPEG)$', caseSensitive: false);
  static final RegExp _cameraVideo =
      RegExp(r'^REC[^/\\]*\.MP4$', caseSensitive: false);
  static final RegExp _watermarkedPhoto =
      RegExp(r'^CAP[^/\\]*\.(?:JPG|JPEG)\.WATERMARKED\.JPG$',
          caseSensitive: false);

  static bool _isManagedCapture(String path) {
    final name = path.split(Platform.pathSeparator).last;
    return _cameraPhoto.hasMatch(name) ||
        _cameraVideo.hasMatch(name) ||
        _watermarkedPhoto.hasMatch(name);
  }

  /// Returns how many files were deleted. Never throws.
  Future<int> sweep() async {
    try {
      final directory = await _temporaryDirectory();
      if (!await directory.exists()) return 0;
      final cutoff = _clock().subtract(minAge);
      var deleted = 0;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !_isManagedCapture(entity.path)) continue;
        try {
          final stat = await entity.stat();
          if (stat.modified.isAfter(cutoff)) continue;
          await entity.delete();
          deleted++;
        } on FileSystemException {
          // In use or already gone; try again on the next launch.
        }
      }
      return deleted;
    } catch (_) {
      return 0;
    }
  }
}
