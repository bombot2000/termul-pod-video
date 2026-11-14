import 'dart:io';

import 'package:gal/gal.dart';

import '../models/pod_media_record.dart';

class GalleryMediaService {
  static const albumName = 'Termul POD';

  Future<void> save(PodMediaRecord record) async {
    final file = File(record.path);
    if (!await file.exists()) {
      throw const FileSystemException('File dokumentasi tidak ditemukan.');
    }
    if (await file.length() == 0) {
      throw const FileSystemException('File dokumentasi kosong.');
    }
    if (record.type == 'video') {
      await Gal.putVideo(file.path, album: albumName);
    } else {
      await Gal.putImage(file.path, album: albumName);
    }
  }
}
