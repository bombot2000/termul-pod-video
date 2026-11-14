import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_pod_video/services/temp_media_cleanup.dart';

void main() {
  late Directory directory;
  late TempMediaCleanup cleanup;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('termul_cleanup_test_');
    cleanup = TempMediaCleanup(temporaryDirectory: () async => directory);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  File create(String relativePath, Duration age) {
    final file = File('${directory.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync([1, 2, 3]);
    file.setLastModifiedSync(DateTime.now().subtract(age));
    return file;
  }

  test('deletes old captures and keeps recent ones', () async {
    final oldPhoto = create('CAP1.jpg', const Duration(hours: 7));
    final oldVideo = create('REC1.mp4', const Duration(hours: 8));
    final oldWatermark =
        create('CAP2.jpg.watermarked.jpg', const Duration(hours: 9));
    final recent = create('CAP3.jpg', const Duration(hours: 1));

    final deleted = await cleanup.sweep();

    expect(deleted, 3);
    expect(oldPhoto.existsSync(), isFalse);
    expect(oldVideo.existsSync(), isFalse);
    expect(oldWatermark.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue);
  });

  test('leaves other file types and subdirectories alone', () async {
    final note = create('notes.txt', const Duration(days: 3));
    final nested = create('sub/old.jpg', const Duration(days: 3));

    final deleted = await cleanup.sweep();

    expect(deleted, 0);
    expect(note.existsSync(), isTrue);
    expect(nested.existsSync(), isTrue);
  });

  test('a missing directory is not an error', () async {
    final missing = TempMediaCleanup(
      temporaryDirectory: () async => Directory('${directory.path}/nope'),
    );
    expect(await missing.sweep(), 0);
  });
}
