import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

class PhotoWatermarkService {
  Future<String> createWatermarkedCopy({
    required String sourcePath,
    required DateTime capturedAt,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? address,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('File foto kamera tidak ditemukan.');
    }

    final timestamp = DateFormat('dd MMM yyyy  HH:mm:ss').format(capturedAt);
    final gpsLine = latitude == null || longitude == null
        ? 'GPS tidak tersedia'
        : 'GPS  ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    final accuracyLine = accuracy == null
        ? 'Akurasi GPS tidak tersedia'
        : 'Akurasi  ${accuracy.toStringAsFixed(1)} m';
    final outputPath = '${source.path}.watermarked.jpg';

    await Isolate.run(
      () => _renderWatermark(
        sourcePath: source.path,
        outputPath: outputPath,
        timestamp: timestamp,
        gpsLine: gpsLine,
        accuracyLine: accuracyLine,
        address: address,
      ),
    );
    return outputPath;
  }
}

void _renderWatermark({
  required String sourcePath,
  required String outputPath,
  required String timestamp,
  required String gpsLine,
  required String accuracyLine,
  required String? address,
}) {
  final sourceFile = File(sourcePath);
  final bytes = sourceFile.readAsBytesSync();
  final decoded = img.decodeJpg(bytes);
  if (decoded == null) {
    throw const FormatException('File foto bukan JPEG yang valid.');
  }

  final photo = img.bakeOrientation(decoded);
  final font = photo.width >= 2400
      ? img.arial48
      : photo.width >= 1200
          ? img.arial24
          : img.arial14;
  final padding = (photo.width * 0.025).round().clamp(12, 64);
  final lines = <String>[
    'TERMUL POD  |  PROOF OF DELIVERY',
    timestamp,
    gpsLine,
    accuracyLine,
  ];
  if (address != null && address.trim().isNotEmpty) {
    final maxChars =
        ((photo.width - padding * 4) / (font.lineHeight * 0.55))
            .floor()
            .clamp(18, 100)
            .toInt();
    lines.addAll(_wrapAddress('Alamat  ${address.trim()}', maxChars));
  }
  final lineGap = (font.lineHeight * 0.35).round();
  final lineHeight = font.lineHeight + lineGap;
  final panelHeight = padding * 2 + lineHeight * lines.length;
  final left = padding;
  final right = photo.width - padding - 1;
  final top = photo.height - panelHeight - padding;
  final bottom = photo.height - padding - 1;

  img.fillRect(
    photo,
    x1: left,
    y1: top,
    x2: right,
    y2: bottom,
    color: img.ColorRgba8(8, 18, 16, 190),
  );

  var textY = top + padding;
  for (var index = 0; index < lines.length; index++) {
    img.drawString(
      photo,
      lines[index],
      font: font,
      x: left + padding,
      y: textY,
      color: index == 0
          ? img.ColorRgb8(125, 235, 199)
          : img.ColorRgb8(255, 255, 255),
    );
    textY += lineHeight;
  }

  final output = File(outputPath);
  output.writeAsBytesSync(img.encodeJpg(photo, quality: 92), flush: true);
}

List<String> _wrapAddress(String value, int maxChars) {
  final words = value.split(RegExp(r'\s+'));
  final lines = <String>[];
  var current = '';
  var truncated = false;

  for (final word in words) {
    final candidate = current.isEmpty ? word : '$current $word';
    if (candidate.length > maxChars && current.isNotEmpty) {
      lines.add(current);
      current = word;
      if (lines.length == 2) {
        truncated = true;
        break;
      }
    } else {
      current = candidate;
    }
  }

  if (current.isNotEmpty && lines.length < 2) {
    lines.add(current);
  } else if (current.isNotEmpty) {
    truncated = true;
  }
  if (truncated && lines.isNotEmpty) {
    lines[lines.length - 1] = '${lines.last}…';
  }
  return lines;
}
