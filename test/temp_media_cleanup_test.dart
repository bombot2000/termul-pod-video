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

  test('deletes only old derived photo when its raw capture remains', () async {
    final oldPhoto = create('CAP1.jpg', const Duration(hours: 7));
    final oldVideo = create('REC1.mp4', const Duration(hours: 8));
    final watermarkSource = create('CAP2.jpg', const Duration(hours: 9));
    final oldWatermark = create(
      'CAP2.jpg.watermarked.jpg',
      const Duration(hours: 9),
    );
    final orphanWatermark = create(
      'CAP_ORPHAN.jpg.watermarked.jpg',
      const Duration(hours: 9),
    );
    final recent = create('CAP3.jpg', const Duration(hours: 1));

    final deleted = await cleanup.sweep();

    expect(deleted, 1);
    expect(oldPhoto.existsSync(), isTrue);
    expect(oldVideo.existsSync(), isTrue);
    expect(watermarkSource.existsSync(), isTrue);
    expect(oldWatermark.existsSync(), isFalse);
    expect(orphanWatermark.existsSync(), isTrue);
    expect(recent.existsSync(), isTrue);
  });

  test('leaves unrelated files and subdirectories alone', () async {
    final note = create('notes.txt', const Duration(days: 3));
    final unrelatedPhoto = create('holiday.jpg', const Duration(days: 3));
    final unrelatedVideo = create('export.mp4', const Duration(days: 3));
    final nested = create(
      'sub/CAP_OLD.jpg.watermarked.jpg',
      const Duration(days: 3),
    );
    create('sub/CAP_OLD.jpg', const Duration(days: 3));

    final deleted = await cleanup.sweep();

    expect(deleted, 0);
    expect(note.existsSync(), isTrue);
    expect(unrelatedPhoto.existsSync(), isTrue);
    expect(unrelatedVideo.existsSync(), isTrue);
    expect(nested.existsSync(), isTrue);
  });

  test('a missing directory is not an error', () async {
    final missing = TempMediaCleanup(
      temporaryDirectory: () async => Directory('${directory.path}/nope'),
    );
    expect(await missing.sweep(), 0);
  });
}
