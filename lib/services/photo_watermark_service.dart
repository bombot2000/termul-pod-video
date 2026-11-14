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
