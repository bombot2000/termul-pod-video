import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pod_media_record.dart';

class PodStorageService {
  static const _recordsKey = 'termul_pod_media_records_v1';

  Future<List<PodMediaRecord>> getRecords() async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_recordsKey) ?? const <String>[];
    final records = <PodMediaRecord>[];
    for (final value in values) {
      try {
        records.add(PodMediaRecord.fromJson(jsonDecode(value) as Map<String, dynamic>));
      } on FormatException {
        // Skip a damaged entry while preserving the remaining records.
      } on TypeError {
        // Skip an entry with an unexpected schema.
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
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw const FileSystemException('File kamera tidak ditemukan.');
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}${Platform.pathSeparator}pod_media');
    await folder.create(recursive: true);
    final extension = type == 'video' ? 'mp4' : 'jpg';
    final stamp = createdAt.toUtc().toIso8601String().replaceAll(':', '-');
    final destination = File('${folder.path}${Platform.pathSeparator}pod_${stamp}.$extension');
    await source.copy(destination.path);
    final record = PodMediaRecord(path: destination.path, type: type, createdAt: createdAt,
      latitude: latitude, longitude: longitude, accuracy: accuracy);
    final preferences = await SharedPreferences.getInstance();
    final records = await getRecords();
    records.insert(0, record);
    await preferences.setStringList(_recordsKey, records.map((item) => jsonEncode(item.toJson())).toList());
    return record;
  }

  Future<void> deleteRecord(PodMediaRecord record) async {
    final file = File(record.path);
    if (await file.exists()) await file.delete();
    final preferences = await SharedPreferences.getInstance();
    final records = await getRecords();
    records.removeWhere((item) => item.path == record.path);
    await preferences.setStringList(_recordsKey, records.map((item) => jsonEncode(item.toJson())).toList());
  }
}
