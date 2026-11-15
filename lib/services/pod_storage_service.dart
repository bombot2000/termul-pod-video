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

  Map<String, dynamic>? _decodeRawRecord(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  List<String> _rawRecords(SharedPreferences preferences) =>
      preferences.getStringList(_recordsKey) ?? const <String>[];

  Future<List<PodMediaRecord>> getRecords() async {
    final preferences = await SharedPreferences.getInstance();
    final records = <PodMediaRecord>[];
    for (final value in _rawRecords(preferences)) {
      final json = _decodeRawRecord(value);
      if (json == null) continue;
      try {
        records.add(PodMediaRecord.fromJson(json));
      } on TypeError {
        // Ignore entries written by an incompatible schema.
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
        // Add the new entry without parsing/re-encoding older entries. This
        // keeps fields from newer app versions and damaged-but-preservable
        // records intact when an older app saves another capture.
        final values = <String>[
          jsonEncode(record.toJson()),
          ..._rawRecords(preferences),
        ];
        final saved = await preferences.setStringList(_recordsKey, values);
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
      final values = _rawRecords(preferences);
      final index = values.indexWhere((value) {
        return _decodeRawRecord(value)?['path'] == record.path;
      });
      if (index < 0) {
        throw const FileSystemException(
          'Dokumentasi tidak ditemukan di riwayat.',
        );
      }

      // Update only the requested property in the original JSON object. All
      // fields not understood by this app version remain untouched.
      final json = _decodeRawRecord(values[index]);
      if (json == null) {
        throw const FileSystemException(
          'Data dokumentasi tidak dapat dibaca.',
        );
      }
      json['gallerySaved'] = saved;
      values[index] = jsonEncode(json);

      final persisted = await preferences.setStringList(_recordsKey, values);
      if (!persisted) {
        throw const FileSystemException('Status Galeri gagal disimpan.');
      }
      return record.copyWith(gallerySaved: saved);
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
      case FileSystemEntityType.pipe:
      case FileSystemEntityType.unixDomainSock:
        throw FileSystemException(
          'Tipe file dokumentasi tidak didukung untuk dipindahkan.',
          path,
        );
    }
    // Keep an explicit terminal path for SDK/analyzer versions that do not
    // promote this platform enum switch to an exhaustive return.
    throw FileSystemException(
      'Tipe file dokumentasi tidak dikenal untuk dipindahkan.',
      path,
    );
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
      case FileSystemEntityType.pipe:
      case FileSystemEntityType.unixDomainSock:
        throw FileSystemException(
          'Tipe file dokumentasi tidak didukung untuk dihapus.',
          path,
        );
    }
  }

  Future<void> deleteRecord(PodMediaRecord record) {
    return _serializeWrite(() async {
      final preferences = await SharedPreferences.getInstance();
      // Keep the raw entries for exact rollback and preserve every unrelated
      // record, including fields and entries this app version cannot parse.
      final previousValues = _rawRecords(preferences);
      final remainingValues = previousValues
          .where((value) => _decodeRawRecord(value)?['path'] != record.path)
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
          remainingValues,
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
            previousValues,
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
