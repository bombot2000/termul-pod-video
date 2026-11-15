import 'dart:convert';
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

  test('concurrent captures keep both files and history records', () async {
    final secondSource = File('${root.path}/second_camera_source.jpg');
    await secondSource.writeAsBytes([1, 3, 5, 7]);

    // Different service instances are used by separate screens/routes.
    // Their writes must still share the same in-process serialization queue.
    final otherStorage = PodStorageService(
      documentsDirectoryProvider: () async => root,
    );
    final saved = await Future.wait([
      storage.saveMedia(
        sourcePath: source.path,
        type: 'photo',
        createdAt: createdAt,
        moveSource: true,
      ),
      otherStorage.saveMedia(
        sourcePath: secondSource.path,
        type: 'photo',
        createdAt: createdAt,
        moveSource: true,
      ),
    ]);

    final records = await storage.getRecords();
    expect(records, hasLength(2));
    expect(saved.map((record) => record.path).toSet(), hasLength(2));
    final contents = await Future.wait(
      saved.map((record) async {
        final bytes = await File(record.path).readAsBytes();
        return bytes.join(',');
      }),
    );
    expect(contents.toSet(), {'9,8,7,6', '1,3,5,7'});
    expect(await source.exists(), isFalse);
    expect(await secondSource.exists(), isFalse);
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
      locationClockOffsetSeconds: -60,
    );

    await storage.updateGalleryStatus(saved, true);
    final restored = (await storage.getRecords()).single;

    expect(restored.locationMocked, isTrue);
    expect(restored.locationAgeSeconds, 7);
    expect(restored.locationClockOffsetSeconds, -60);
    expect(restored.accuracy, 12.5);
    expect(restored.gallerySaved, isTrue);
  });

  test('saving another capture preserves unknown fields in older entries',
      () async {
    final first = await storage.saveMedia(
      sourcePath: source.path,
      type: 'photo',
      createdAt: createdAt,
    );
    final preferences = await SharedPreferences.getInstance();
    final firstJson = <String, dynamic>{
      ...first.toJson(),
      'futureField': <String, dynamic>{'preserve': true},
    };
    await preferences.setStringList(
      'termul_pod_media_records_v1',
      [jsonEncode(firstJson)],
    );

    final secondSource = File('${root.path}/second_camera_source.jpg');
    await secondSource.writeAsBytes([1, 2, 3]);
    await storage.saveMedia(
      sourcePath: secondSource.path,
      type: 'photo',
      createdAt: createdAt.add(const Duration(seconds: 1)),
    );

    final values = preferences.getStringList('termul_pod_media_records_v1')!;
    final retained = values
        .map((value) => jsonDecode(value) as Map<String, dynamic>)
        .singleWhere((json) => json['path'] == first.path);
    expect(retained['futureField'], {'preserve': true});
  });

  test('gallery status update preserves unknown fields', () async {
    final record = await storage.saveMedia(
      sourcePath: source.path,
      type: 'photo',
      createdAt: createdAt,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'termul_pod_media_records_v1',
      [
        jsonEncode(<String, dynamic>{
          ...record.toJson(),
          'futureField': <String, dynamic>{'preserve': true},
        }),
      ],
    );

    await storage.updateGalleryStatus(record, true);

    final json = jsonDecode(
      preferences.getStringList('termul_pod_media_records_v1')!.single,
    ) as Map<String, dynamic>;
    expect(json['gallerySaved'], isTrue);
    expect(json['futureField'], {'preserve': true});
  });

  test('deleting one record preserves unknown fields in remaining records',
      () async {
    final first = await storage.saveMedia(
      sourcePath: source.path,
      type: 'photo',
      createdAt: createdAt,
    );
    final secondSource = File('${root.path}/second_camera_source.jpg');
    await secondSource.writeAsBytes([1, 2, 3]);
    final second = await storage.saveMedia(
      sourcePath: secondSource.path,
      type: 'photo',
      createdAt: createdAt.add(const Duration(seconds: 1)),
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'termul_pod_media_records_v1',
      [
        jsonEncode(<String, dynamic>{
          ...second.toJson(),
          'futureField': <String, dynamic>{'preserve': true},
        }),
        jsonEncode(first.toJson()),
      ],
    );

    await storage.deleteRecord(first);

    final values = preferences.getStringList('termul_pod_media_records_v1')!;
    expect(values, hasLength(1));
    final retained = jsonDecode(values.single) as Map<String, dynamic>;
    expect(retained['path'], second.path);
    expect(retained['futureField'], {'preserve': true});
    expect(await File(second.path).exists(), isTrue);
    expect(await File(first.path).exists(), isFalse);
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
    expect(restored.locationClockOffsetSeconds, isNull);
    expect(restored.latitude, -7.9826);
  });

  test('failed media deletion restores the history record and evidence', () async {
    final record = await storage.saveMedia(
      sourcePath: source.path,
      type: 'photo',
      createdAt: createdAt,
    );

    // Simulate a record written by a newer app version. The current model
    // does not know this field, so rollback must restore the raw JSON exactly.
    final preferences = await SharedPreferences.getInstance();
    final previousValues = <String>[
      jsonEncode(<String, dynamic>{
        ...record.toJson(),
        'futureField': <String, dynamic>{'preserve': true},
      }),
    ];
    await preferences.setStringList(
      'termul_pod_media_records_v1',
      previousValues,
    );

    // A non-empty directory at the media path forces the final delete to fail
    // after the reversible quarantine rename has succeeded.
    await File(record.path).delete();
    final evidenceDirectory = Directory(record.path);
    await evidenceDirectory.create();
    final evidenceFile = File('${evidenceDirectory.path}/evidence.bin');
    await evidenceFile.writeAsBytes([4, 5, 6]);

    await expectLater(
      storage.deleteRecord(record),
      throwsA(isA<FileSystemException>()),
    );

    final restoredRecords = await storage.getRecords();
    expect(restoredRecords, hasLength(1));
    expect(restoredRecords.single.path, record.path);
    expect(
      preferences.getStringList('termul_pod_media_records_v1'),
      previousValues,
      reason: 'Rollback must preserve unknown JSON fields byte-for-byte.',
    );
    expect(await evidenceDirectory.exists(), isTrue);
    expect(await evidenceFile.readAsBytes(), [4, 5, 6]);
  });
}
