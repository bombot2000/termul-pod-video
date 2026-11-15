import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import 'pod_watermark_settings_service.dart';
import 'watermark_text_layout.dart';

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

    final layout = await PodWatermarkSettingsService().loadLayout();
    await Isolate.run(
      () => _renderWatermark(
        sourcePath: source.path,
        outputPath: outputPath,
        timestamp: timestamp,
        gpsLine: gpsLine,
        accuracyLine: accuracyLine,
        address: address,
        layout: layout.name,
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
  required String layout,
}) {
  final sourceFile = File(sourcePath);
  final bytes = sourceFile.readAsBytesSync();
  final decoded = img.decodeJpg(bytes);
  if (decoded == null) {
    throw const FormatException('File foto bukan JPEG yang valid.');
  }

  final photo = img.bakeOrientation(decoded);
  final compact = layout == 'compact';
  final header = layout == 'header';
  final font = photo.width >= 2400
      ? img.arial48
      : photo.width >= 1200
          ? img.arial24
          : img.arial14;
  final activeFont = compact
      ? (photo.width >= 2400 ? img.arial24 : img.arial14)
      : font;
  final padding = (photo.width * 0.025).round().clamp(12, 64);
  final panelWidth =
      compact ? (photo.width * 0.72).round() : photo.width - padding * 2;

  // Estimate a safe character width from the active bitmap font and the
  // actual text area. GPS coordinates can be wider than the compact panel.
  final contentWidth = (panelWidth - padding * 2).clamp(1, photo.width);
  final maxChars = (contentWidth / (activeFont.lineHeight * 0.55))
      .floor()
      .clamp(12, 100)
      .toInt();

  final gpsLines = wrapWatermarkText(gpsLine, maxChars);
  final accuracyLines = wrapWatermarkText(accuracyLine, maxChars);
  final addressLines = address == null || address.trim().isEmpty
      ? <String>[]
      : wrapWatermarkText('Alamat  ${address.trim()}', maxChars);

  final visibleLines = compact
      ? <String>[
          timestamp,
          ...gpsLines,
          ...accuracyLines,
          ...addressLines,
        ]
      : <String>[
          'TERMUL POD  |  PROOF OF DELIVERY',
          timestamp,
          ...gpsLines,
          ...accuracyLines,
          ...addressLines,
        ];

  final lineGap = (activeFont.lineHeight * 0.35).round();
  final lineHeight = activeFont.lineHeight + lineGap;
  final panelHeight = padding * 2 + lineHeight * visibleLines.length;
  final left = padding;
  final right = left + panelWidth;
  final top = header ? padding : photo.height - panelHeight - padding;
  final bottom = top + panelHeight;

  img.fillRect(
    photo,
    x1: left,
    y1: top,
    x2: right,
    y2: bottom,
    color: img.ColorRgba8(8, 18, 16, 190),
  );
  if (header) {
    img.fillRect(
      photo,
      x1: left,
      y1: top,
      x2: left + (padding * 0.35).round(),
      y2: bottom,
      color: img.ColorRgb8(101, 214, 176),
    );
  }

  var textY = top + padding;
  for (var index = 0; index < visibleLines.length; index++) {
    img.drawString(
      photo,
      visibleLines[index],
      font: activeFont,
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
