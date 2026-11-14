import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:termul_pod_video/models/pod_media_record.dart';
import 'package:termul_pod_video/services/pod_storage_service.dart';

void main() {
  late Directory root;
  late File source;
  late PodStorageService storage;
  final createdAt = DateTime.parse('2026-11-14T09:30:00.000');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('termul_capture_test_');
    source = File('${root.path}/camera_source.jpg');
    await source.writeAsBytes([9, 8, 7, 6]);
    storage = PodStorageService(documentsDirectoryProvider: () async => root);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('moveSource moves the capture instead of leaving a duplicate', () async {
    final record = await storage.saveMedia(
      sourcePath: source.path,
      type: 'photo',
      createdAt: createdAt,
      moveSource: true,
    );

    expect(await source.exists(), isFalse);
    expect(await File(record.path).readAsBytes(), [9, 8, 7, 6]);
    expect((await storage.getRecords()).single.path, record.path);
  });

  test('the default still copies and keeps the source', () async {
    final record = await storage.saveMedia(
      sourcePath: source.path,
      type: 'photo',
      createdAt: createdAt,
    );

    expect(await source.exists(), isTrue);
    expect(await File(record.path).exists(), isTrue);
  });

  test('GPS trust metadata is stored and survives a gallery update', () async {
    final saved = await storage.saveMedia(
      sourcePath: source.path,
      type: 'photo',
      createdAt: createdAt,
      latitude: -7.9826,
      longitude: 112.6308,
      accuracy: 12.5,
      locationMocked: true,
      locationAgeSeconds: 7,
    );

    await storage.updateGalleryStatus(saved, true);
    final restored = (await storage.getRecords()).single;

    expect(restored.locationMocked, isTrue);
    expect(restored.locationAgeSeconds, 7);
    expect(restored.accuracy, 12.5);
    expect(restored.gallerySaved, isTrue);
  });

  test('copyWith changes only the gallery flag', () {
    final original = PodMediaRecord(
      path: '/private/pod_media/a.jpg',
      type: 'photo',
      createdAt: createdAt,
      latitude: -7.9826,
      longitude: 112.6308,
      accuracy: 5,
      address: 'Malang',
      watermarkApplied: true,
      locationMocked: false,
      locationAgeSeconds: 2,
    );

    final updated = original.copyWith(gallerySaved: true);

    expect(updated.gallerySaved, isTrue);
    expect(updated.path, original.path);
    expect(updated.address, 'Malang');
    expect(updated.watermarkApplied, isTrue);
    expect(updated.locationMocked, isFalse);
    expect(updated.locationAgeSeconds, 2);
  });

  test('records written before the GPS metadata existed stay readable', () {
    final restored = PodMediaRecord.fromJson({
      'path': '/private/pod_media/old.jpg',
      'type': 'photo',
      'createdAt': '2026-11-14T09:30:00.000',
      'latitude': -7.9826,
      'longitude': 112.6308,
    });

    expect(restored.locationMocked, isNull);
    expect(restored.locationAgeSeconds, isNull);
    expect(restored.latitude, -7.9826);
  });
}
