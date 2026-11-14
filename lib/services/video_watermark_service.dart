import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:intl/intl.dart';
import 'package:watermark_kit/watermark_kit.dart';

import 'pod_watermark_settings_service.dart';

class VideoWatermarkService {
  VideoWatermarkService({WatermarkKit? watermarkKit})
      : _watermarkKit = watermarkKit ?? WatermarkKit();

  final WatermarkKit _watermarkKit;

  Future<String> createWatermarkedCopy({
    required String sourcePath,
    required DateTime capturedAt,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? address,
    void Function(double)? onProgress,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('File video kamera tidak ditemukan.');
    }

    final layout = await PodWatermarkSettingsService().loadLayout();
    final overlay = await VideoWatermarkOverlay.render(
      capturedAt: capturedAt,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      address: address,
      layout: layout.name,
    );
    final task = await _watermarkKit.composeVideo(
      inputVideoPath: source.path,
      watermarkImage: overlay,
      anchor: layout == PodWatermarkLayout.header ? 'topLeft' : 'bottomLeft',
      margin: 0.025,
      marginUnit: 'percent',
      widthPercent: 0.94,
      opacity: 1,
      codec: 'h264',
    );

    final subscription = task.progress.listen((progress) {
      onProgress?.call(progress.clamp(0.0, 1.0).toDouble());
    });
    try {
      final result = await task.done;
      final output = File(result.path);
      if (output.path == source.path ||
          !await output.exists() ||
          await output.length() == 0) {
        throw const FileSystemException(
          'Hasil video ber-watermark tidak valid.',
        );
      }
      return output.path;
    } finally {
      await subscription.cancel();
    }
  }
}

class VideoWatermarkOverlay {
  static Future<Uint8List> render({
    required DateTime capturedAt,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? address,
    String layout = 'classic',
  }) async {
    const width = 1600;
    const height = 260;
    const horizontalPadding = 48.0;
    final compact = layout == 'compact';
    final header = layout == 'header';
    final panelWidth = compact ? 1180.0 : width.toDouble();
    final panelHeight = compact ? 230.0 : height.toDouble();
    final panelTop = header || !compact ? 0.0 : height - panelHeight;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    final panel = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(0, panelTop, panelWidth, panelHeight),
      const ui.Radius.circular(28),
    );
    canvas.drawRRect(
      panel,
      ui.Paint()..color = const ui.Color.fromARGB(224, 7, 19, 17),
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(0, panelTop, 10, panelHeight),
        const ui.Radius.circular(5),
      ),
      ui.Paint()..color = const ui.Color(0xFF65D6B0),
    );

    void drawLine(
      String value, {
      required double top,
      required double fontSize,
      required ui.Color color,
      FontWeight weight = FontWeight.w600,
      int maxLines = 1,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: weight,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(maxWidth: width - horizontalPadding * 2);
      painter.paint(canvas, ui.Offset(horizontalPadding, panelTop + top));
      painter.dispose();
    }

    final timestamp = DateFormat('dd MMM yyyy  HH:mm:ss').format(capturedAt);
    final gps = latitude == null || longitude == null
        ? 'GPS tidak tersedia'
        : 'GPS  ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    final accuracyText = accuracy == null
        ? 'Akurasi GPS tidak tersedia'
        : 'Akurasi  ${accuracy.toStringAsFixed(1)} m';
    final location = address?.trim().isNotEmpty == true
        ? 'Alamat  ${address!.trim()}'
        : 'Alamat lokasi tidak tersedia';

    if (compact) {
      drawLine(
        timestamp,
        top: 18,
        fontSize: 35,
        color: const ui.Color(0xFF79E5C2),
        weight: FontWeight.w800,
      );
      drawLine(gps, top: 68, fontSize: 27,
          color: const ui.Color(0xFFFFFFFF));
      drawLine(accuracyText, top: 108, fontSize: 25,
          color: const ui.Color(0xFFE0EAE6));
      drawLine(location, top: 148, fontSize: 24,
          color: const ui.Color(0xFFE0EAE6), maxLines: 2);
    } else if (header) {
      drawLine('TERMUL POD  •  PROOF OF DELIVERY', top: 16,
          fontSize: 28, color: const ui.Color(0xFF79E5C2),
          weight: FontWeight.w800);
      drawLine(timestamp, top: 56, fontSize: 38,
          color: const ui.Color(0xFFFFFFFF), weight: FontWeight.w800);
      drawLine(gps, top: 108, fontSize: 30,
          color: const ui.Color(0xFFFFFFFF));
      drawLine(accuracyText, top: 150, fontSize: 28,
          color: const ui.Color(0xFFE0EAE6));
      drawLine(location, top: 190, fontSize: 27,
          color: const ui.Color(0xFFE0EAE6), maxLines: 2);
    } else {
      drawLine('TERMUL POD  •  PROOF OF DELIVERY', top: 20,
          fontSize: 28, color: const ui.Color(0xFF79E5C2),
          weight: FontWeight.w800);
      drawLine(timestamp, top: 60, fontSize: 38,
          color: const ui.Color(0xFFFFFFFF), weight: FontWeight.w800);
      drawLine(gps, top: 112, fontSize: 30,
          color: const ui.Color(0xFFFFFFFF));
      drawLine(accuracyText, top: 154, fontSize: 28,
          color: const ui.Color(0xFFE0EAE6));
      drawLine(location, top: 194, fontSize: 27,
          color: const ui.Color(0xFFE0EAE6), maxLines: 2);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (data == null) {
      throw const FormatException('Overlay watermark video gagal dibuat.');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
