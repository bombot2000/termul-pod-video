import 'dart:async';
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

  // Serialize every read-modify-write transaction. SharedPreferences does not
  // provide an atomic append, so concurrent captures/gallery updates/deletes
  // could otherwise overwrite one another's record list.
  static Future<void> _writeQueue = Future<void>.value();

  Future<T> _serializeWrite<T>(Future<T> Function() action) async {
    final previous = _writeQueue;
    final gate = Completer<void>();
    _writeQueue = gate.future;
    await previous;
    try {
      return await action();
    } finally {
      gate.complete();
    }
  }

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
    String? address,
    bool? watermarkApplied,
    bool? locationMocked,
    int? locationAgeSeconds,
    int? locationClockOffsetSeconds,
    bool moveSource = false,
  }) {
    return _serializeWrite(() async {
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

      // With [moveSource] the capture is renamed into place instead of being
      // copied, so no duplicate is left behind in the cache directory.
      var moved = false;
      if (moveSource) {
        try {
          await source.rename(destination.path);
          moved = true;
        } on FileSystemException {
          // Different filesystem: fall back to copy and delete after indexing.
          await source.copy(destination.path);
        }
      } else {
        await source.copy(destination.path);
      }
      final record = PodMediaRecord(
        path: destination.path,
        type: type,
        createdAt: createdAt,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        address: address,
        watermarkApplied: watermarkApplied,
        locationMocked: locationMocked,
        locationAgeSeconds: locationAgeSeconds,
        locationClockOffsetSeconds: locationClockOffsetSeconds,
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
        if (moved) {
          // Put the capture back: it was the only copy, so never delete it.
          try {
            await destination.rename(source.path);
          } on FileSystemException {
            // Keep it in pod_media rather than lose the evidence.
          }
        } else if (await destination.exists()) {
          // Do not leave an unindexed media file after a metadata write failure.
          await destination.delete();
        }
        rethrow;
      }

      if (moveSource && !moved && await source.exists()) {
        try {
          await source.delete();
        } on FileSystemException {
          // Best effort; the indexed copy is safe.
        }
      }

      return record;
    });
  }

  Future<PodMediaRecord> updateGalleryStatus(
    PodMediaRecord record,
    bool saved,
  ) {
    return _serializeWrite(() async {
      final preferences = await SharedPreferences.getInstance();
      final records = await getRecords();
      final index = records.indexWhere((item) => item.path == record.path);
      if (index < 0) {
        throw const FileSystemException(
          'Dokumentasi tidak ditemukan di riwayat.',
        );
      }
      final updated = record.copyWith(gallerySaved: saved);
      records[index] = updated;
      final persisted = await preferences.setStringList(
        _recordsKey,
        records.map((item) => jsonEncode(item.toJson())).toList(),
      );
      if (!persisted) {
        throw const FileSystemException('Status Galeri gagal disimpan.');
      }
      return updated;
    });
  }

  Future<FileSystemEntity?> _renameEntity(
    String path,
    String destination,
  ) async {
    switch (await FileSystemEntity.type(path)) {
      case FileSystemEntityType.file:
        return File(path).rename(destination);
      case FileSystemEntityType.directory:
        return Directory(path).rename(destination);
      case FileSystemEntityType.link:
        return Link(path).rename(destination);
      case FileSystemEntityType.notFound:
        return null;
      case FileSystemEntityType.other:
        throw FileSystemException('Tipe file dokumentasi tidak didukung.', path);
    }
  }

  Future<void> _deleteEntity(String path) async {
    switch (await FileSystemEntity.type(path)) {
      case FileSystemEntityType.file:
        await File(path).delete();
        return;
      case FileSystemEntityType.directory:
        await Directory(path).delete();
        return;
      case FileSystemEntityType.link:
        await Link(path).delete();
        return;
      case FileSystemEntityType.notFound:
        return;
      case FileSystemEntityType.other:
        throw FileSystemException('Tipe file dokumentasi tidak didukung.', path);
    }
  }

  Future<void> deleteRecord(PodMediaRecord record) {
    return _serializeWrite(() async {
      final preferences = await SharedPreferences.getInstance();
      final records = await getRecords();
      final remaining = records
          .where((item) => item.path != record.path)
          .toList(growable: false);

      // Move the evidence to a sibling quarantine path first. A same-directory
      // rename is reversible, unlike deleting the file before the index update.
      final quarantinePath =
          '${record.path}.deleting-${DateTime.now().microsecondsSinceEpoch}';
      final moved = await _renameEntity(record.path, quarantinePath);

      bool saved;
      try {
        saved = await preferences.setStringList(
          _recordsKey,
          remaining.map((item) => jsonEncode(item.toJson())).toList(),
        );
      } catch (_) {
        if (moved != null) {
          await _renameEntity(quarantinePath, record.path);
        }
        rethrow;
      }
      if (!saved) {
        if (moved != null) {
          await _renameEntity(quarantinePath, record.path);
        }
        throw const FileSystemException(
          'Riwayat tidak berhasil diperbarui. File dokumentasi dipulihkan.',
        );
      }

      if (moved == null) return;
      try {
        await _deleteEntity(quarantinePath);
      } catch (error) {
        // If the media cannot be deleted, restore both its original path and
        // history entry so the user does not lose access to the evidence.
        await _renameEntity(quarantinePath, record.path);
        bool restored;
        try {
          restored = await preferences.setStringList(
            _recordsKey,
            records.map((item) => jsonEncode(item.toJson())).toList(),
          );
        } catch (restoreError) {
          // Keep the evidence even if the index itself cannot be restored.
          await _renameEntity(record.path, quarantinePath);
          throw FileSystemException(
            'File gagal dihapus dan riwayat gagal dipulihkan: $restoreError. Bukti disimpan di $quarantinePath',
            quarantinePath,
          );
        }
        if (!restored) {
          await _renameEntity(record.path, quarantinePath);
          throw FileSystemException(
            'File gagal dihapus dan riwayat gagal dipulihkan. Bukti disimpan di $quarantinePath ($error)',
            quarantinePath,
          );
        }
        rethrow;
      }
    });
  }
}
