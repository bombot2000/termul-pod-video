import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Removes stale photo-watermark intermediates when the original capture
/// still exists. Raw camera captures and unknown video outputs are never swept:
/// after an interrupted save they may be the only remaining POD evidence.
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

  static final RegExp _watermarkedPhoto =
      RegExp(r'^CAP[^/]*\.(?:JPG|JPEG)\.WATERMARKED\.JPG$',
          caseSensitive: false);

  /// Returns how many safe intermediate files were deleted. Never throws.
  Future<int> sweep() async {
    try {
      final directory = await _temporaryDirectory();
      if (!await directory.exists()) return 0;
      final cutoff = _clock().subtract(minAge);
      var deleted = 0;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!_watermarkedPhoto.hasMatch(name)) continue;

        // The derived image is disposable only while its original camera
        // capture is still present. If it is the only copy, preserve it.
        final originalPath = entity.path.substring(
          0,
          entity.path.length - '.watermarked.jpg'.length,
        );
        final original = File(originalPath);
        try {
          final derivedStat = await entity.stat();
          if (derivedStat.modified.isAfter(cutoff)) continue;
          if (!await original.exists()) continue;
          final originalStat = await original.stat();
          if (originalStat.modified.isAfter(cutoff)) continue;
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
