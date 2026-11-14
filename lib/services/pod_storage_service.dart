import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pod_media_record.dart';

class PodStorageService {
  static const _recordsKey = 'termul_pod_media_records_v1';

  Future<Directory> mediaDirectory({required bool video}) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}/pod_media/${video ? 'videos' : 'photos'}',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<PodMediaRecord> importCapture({
    required String sourcePath,
    required bool video,
    required DateTime capturedAt,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('File hasil kamera tidak ditemukan');
    }
    final directory = await mediaDirectory(video: video);
    final extension = video ? 'mp4' : 'jpg';
    final id = capturedAt.microsecondsSinceEpoch.toString();
    final destination = File('${directory.path}/pod_$id.$extension');
    await source.copy(destination.path);

    final record = PodMediaRecord(
      id: id,
      path: destination.path,
      type: video ? 'video' : 'photo',
      createdAt: capturedAt,
    );
    await addRecord(record);
    return record;
  }

  Future<List<PodMediaRecord>> loadRecords() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_recordsKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final records = decoded
          .whereType<Map<String, dynamic>>()
          .map(PodMediaRecord.fromJson)
          .where((record) => File(record.path).existsSync())
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  Future<void> addRecord(PodMediaRecord record) async {
    final records = await loadRecords();
    final updated = [record, ...records.where((item) => item.id != record.id)];
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _recordsKey,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> deleteRecord(PodMediaRecord record) async {
    final file = File(record.path);
    if (await file.exists()) await file.delete();
    final records = (await loadRecords())
        .where((item) => item.id != record.id)
        .toList();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _recordsKey,
      jsonEncode(records.map((item) => item.toJson()).toList()),
    );
  }
}
