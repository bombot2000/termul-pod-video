import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:termul_pod_video/services/photo_watermark_service.dart';

void main() {
  late Directory temporaryDirectory;
  late File sourceFile;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('pod_watermark_test_');
    final source = img.Image(width: 640, height: 480);
    img.fill(source, color: img.ColorRgb8(80, 140, 190));
    sourceFile = File('${temporaryDirectory.path}/source.jpg');
    await sourceFile.writeAsBytes(img.encodeJpg(source, quality: 95));
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('burns timestamp and GPS details into a separate JPEG file', () async {
    final outputPath = await PhotoWatermarkService().createWatermarkedCopy(
      sourcePath: sourceFile.path,
      capturedAt: DateTime.parse('2026-11-14T09:30:00'),
      latitude: -7.9826,
      longitude: 112.6308,
      accuracy: 8.5,
      address: 'Jl. Merdeka, Malang, Jawa Timur',
    );

    expect(outputPath, isNot(sourceFile.path));
    expect(await File(outputPath).exists(), isTrue);
    expect(await sourceFile.exists(), isTrue);

    final output = img.decodeJpg(await File(outputPath).readAsBytes());
    expect(output, isNotNull);
    expect(output!.width, 640);
    expect(output.height, 480);

    final originalPixel = img.decodeJpg(await sourceFile.readAsBytes())!.getPixel(10, 10);
    final outputPixel = output.getPixel(10, 10);
    expect(outputPixel.r, closeTo(originalPixel.r, 8));
    expect(outputPixel.g, closeTo(originalPixel.g, 8));
    expect(outputPixel.b, closeTo(originalPixel.b, 8));

    final panelPixel = output.getPixel(20, 450);
    expect(panelPixel.r, lessThan(50));
    expect(panelPixel.g, lessThan(70));
    expect(panelPixel.b, lessThan(70));
  });

  test('watermark remains possible when GPS is unavailable', () async {
    final outputPath = await PhotoWatermarkService().createWatermarkedCopy(
      sourcePath: sourceFile.path,
      capturedAt: DateTime.parse('2026-11-14T09:30:00'),
    );

    expect(await File(outputPath).exists(), isTrue);
  });
}
