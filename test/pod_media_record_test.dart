import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:termul_pod_video/models/pod_media_record.dart';
import 'package:termul_pod_video/services/pod_storage_service.dart';

void main() {
  late Directory temporaryDirectory;
  late File sourceFile;
  late PodStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temporaryDirectory = await Directory.systemTemp.createTemp('termul_pod_test_');
    sourceFile = File('${temporaryDirectory.path}/camera_source.jpg');
    await sourceFile.writeAsBytes([1, 2, 3, 4]);
    storage = PodStorageService(
      documentsDirectoryProvider: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('POD media record preserves timestamp and GPS metadata', () {
    final createdAt = DateTime.parse('2026-11-14T09:30:00.000');
    final original = PodMediaRecord(
      path: '/private/pod_media/pod_test.jpg',
      type: 'photo',
      createdAt: createdAt,
      latitude: -7.9826,
      longitude: 112.6308,
      accuracy: 8.5,
      address: 'Jl. Merdeka, Malang, Jawa Timur',
      watermarkApplied: true,
      gallerySaved: true,
    );

    final restored = PodMediaRecord.fromJson(original.toJson());

    expect(restored.path, original.path);
    expect(restored.type, original.type);
    expect(restored.createdAt, createdAt);
    expect(restored.latitude, -7.9826);
    expect(restored.longitude, 112.6308);
    expect(restored.accuracy, 8.5);
    expect(restored.address, 'Jl. Merdeka, Malang, Jawa Timur');
    expect(restored.watermarkApplied, isTrue);
    expect(restored.gallerySaved, isTrue);
  });

  test('POD media record supports capture without GPS permission', () {
    final original = PodMediaRecord(
      path: '/private/pod_media/pod_no_gps.jpg',
      type: 'photo',
      createdAt: DateTime.parse('2026-11-14T09:30:00.000'),
    );

    final restored = PodMediaRecord.fromJson(original.toJson());

    expect(restored.latitude, isNull);
    expect(restored.longitude, isNull);
    expect(restored.accuracy, isNull);
    expect(restored.address, isNull);
    expect(restored.watermarkApplied, isNull);
    expect(restored.gallerySaved, isNull);
  });

  test('legacy history entries remain readable without watermark status', () {
    final restored = PodMediaRecord.fromJson({
      'path': '/private/pod_media/legacy.jpg',
      'type': 'photo',
      'createdAt': '2026-11-14T09:30:00.000',
    });

    expect(restored.address, isNull);
    expect(restored.watermarkApplied, isNull);
    expect(restored.path, '/private/pod_media/legacy.jpg');
  });

  test('storage persists watermark status with media metadata', () async {
    final saved = await storage.saveMedia(
      sourcePath: sourceFile.path,
      type: 'photo',
      createdAt: DateTime.parse('2026-11-14T09:30:00.000'),
      address: 'Jl. Merdeka, Malang',
      watermarkApplied: true,
    );

    final restored = (await storage.getRecords()).single;
    expect(saved.address, 'Jl. Merdeka, Malang');
    expect(restored.address, 'Jl. Merdeka, Malang');
    expect(restored.watermarkApplied, isTrue);
  });

  test('gallery export status is persisted without changing media metadata', () async {
    final saved = await storage.saveMedia(
      sourcePath: sourceFile.path,
      type: 'video',
      createdAt: DateTime.parse('2026-11-14T09:30:00.000'),
      address: 'Malang',
      watermarkApplied: true,
    );
    final updated = await storage.updateGalleryStatus(saved, true);
    final restored = (await storage.getRecords()).single;
    expect(updated.gallerySaved, isTrue);
    expect(restored.gallerySaved, isTrue);
    expect(restored.path, saved.path);
    expect(restored.address, 'Malang');
    expect(restored.watermarkApplied, isTrue);
  });

  test('same timestamp captures receive unique file names and both persist', () async {
    final createdAt = DateTime.parse('2026-11-14T09:30:00.000');
    final first = await storage.saveMedia(
      sourcePath: sourceFile.path,
      type: 'photo',
      createdAt: createdAt,
    );
    final second = await storage.saveMedia(
      sourcePath: sourceFile.path,
      type: 'photo',
      createdAt: createdAt,
    );

    expect(first.path, isNot(second.path));
    expect(await File(first.path).exists(), isTrue);
    expect(await File(second.path).exists(), isTrue);

    final records = await storage.getRecords();
    expect(records, hasLength(2));
    expect(records.map((record) => record.path).toSet(), hasLength(2));
  });

  test('delete removes the selected file and only its history entry', () async {
    final first = await storage.saveMedia(
      sourcePath: sourceFile.path,
      type: 'photo',
      createdAt: DateTime.parse('2026-11-14T09:30:00.000'),
    );
    final second = await storage.saveMedia(
      sourcePath: sourceFile.path,
      type: 'video',
      createdAt: DateTime.parse('2026-11-14T09:31:00.000'),
    );

    await storage.deleteRecord(first);

    expect(await File(first.path).exists(), isFalse);
    expect(await File(second.path).exists(), isTrue);
    final records = await storage.getRecords();
    expect(records, hasLength(1));
    expect(records.single.path, second.path);
  });
}
