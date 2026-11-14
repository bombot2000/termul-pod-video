import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pod_media_record.dart';

typedef DocumentsDirectoryProvider = Future<Directory> Function();

class PodStorageService {
  PodStorageService({DocumentsDirectoryProvider? documentsDirectoryProvider})
      : _documentsDirectoryProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  static const _recordsKey = 'termul_pod_media_records_v1';
  final DocumentsDirectoryProvider _documentsDirectoryProvider;

  Future<List<PodMediaRecord>> getRecords() async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_recordsKey) ?? const <String>[];
    final records = <PodMediaRecord>[];
    for (final value in values) {
      try {
        records.add(
          PodMediaRecord.fromJson(
            jsonDecode(value) as Map<String, dynamic>,
          ),
        );
      } on FormatException {
        // Preserve valid entries if one persisted entry is damaged.
      } on TypeError {
        // Ignore entries written by an incompatible older schema.
      }
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  Future<PodMediaRecord> saveMedia({
    required String sourcePath,
    required String type,
    required DateTime createdAt,
    double? latitude,
    double? longitude,
    double? accuracy,
    bool? watermarkApplied,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('File kamera tidak ditemukan.');
    }

    final root = await _documentsDirectoryProvider();
    final folder = Directory(
      '${root.path}${Platform.pathSeparator}pod_media',
    );
    await folder.create(recursive: true);

    final extension = type == 'video' ? 'mp4' : 'jpg';
    final stamp = createdAt.toUtc().toIso8601String().replaceAll(':', '-');
    final baseName = 'pod_$stamp';
    var destination = File(
      '${folder.path}${Platform.pathSeparator}$baseName.$extension',
    );
    var suffix = 1;
    while (await destination.exists()) {
      destination = File(
        '${folder.path}${Platform.pathSeparator}'
        '${baseName}_$suffix.$extension',
      );
      suffix++;
    }

    await source.copy(destination.path);
    final record = PodMediaRecord(
      path: destination.path,
      type: type,
      createdAt: createdAt,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      watermarkApplied: watermarkApplied,
    );

    try {
      final preferences = await SharedPreferences.getInstance();
      final records = await getRecords();
      records.insert(0, record);
      final saved = await preferences.setStringList(
        _recordsKey,
        records.map((item) => jsonEncode(item.toJson())).toList(),
      );
      if (!saved) {
        throw const FileSystemException(
          'Indeks dokumentasi tidak berhasil disimpan.',
        );
      }
    } catch (_) {
      // Do not leave an unindexed media file after a metadata write failure.
      if (await destination.exists()) {
        await destination.delete();
      }
      rethrow;
    }

    return record;
  }

  Future<void> deleteRecord(PodMediaRecord record) async {
    final preferences = await SharedPreferences.getInstance();
    final records = await getRecords();
    records.removeWhere((item) => item.path == record.path);
    final saved = await preferences.setStringList(
      _recordsKey,
      records.map((item) => jsonEncode(item.toJson())).toList(),
    );
    if (!saved) {
      throw const FileSystemException(
        'Riwayat tidak berhasil diperbarui. File tidak dihapus.',
      );
    }

    final file = File(record.path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
