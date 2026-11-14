import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Removes stale capture leftovers from the app cache directory.
///
/// The camera plugin writes raw photos/videos there and the watermark steps
/// write derived copies. Normal captures clean up after themselves; this sweep
/// catches what a crash, a kill, or an older build left behind. Only top-level
/// image/video files older than [minAge] are touched.
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

  static const _extensions = ['.jpg', '.jpeg', '.mp4'];

  /// Returns how many files were deleted. Never throws.
  Future<int> sweep() async {
    try {
      final directory = await _temporaryDirectory();
      if (!await directory.exists()) return 0;
      final cutoff = _clock().subtract(minAge);
      var deleted = 0;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.path.toLowerCase();
        if (!_extensions.any(name.endsWith)) continue;
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
