import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:termul_pod_video/services/video_watermark_service.dart';

void main() {
  const capturedAt = DateTime(2026, 11, 15, 9, 30, 0);

  test('renders valid PNG overlays for every supported layout', () async {
    for (final layout in ['classic', 'compact', 'header']) {
      final bytes = await VideoWatermarkOverlay.render(
        capturedAt: capturedAt,
        latitude: -7.9826,
        longitude: 112.6308,
        accuracy: 8.5,
        address: 'Jalan Soekarno Hatta, Lowokwaru, Kota Malang, Jawa Timur',
        layout: layout,
      );

      final decoded = img.decodePng(bytes);
      expect(decoded, isNotNull, reason: 'layout: $layout');
      expect(decoded!.width, 1600, reason: 'layout: $layout');
      expect(decoded.height, 260, reason: 'layout: $layout');
      expect(decoded.getPixel(800, 130).a, greaterThan(200),
          reason: 'the panel should be opaque at its center: $layout');
    }
  });

  test('compact overlay keeps the unused right side transparent', () async {
    final bytes = await VideoWatermarkOverlay.render(
      capturedAt: capturedAt,
      latitude: -7.9826,
      longitude: 112.6308,
      accuracy: 8.5,
      address: 'Alamat panjang untuk menguji pembungkusan teks watermark',
      layout: 'compact',
    );

    final decoded = img.decodePng(bytes);
    expect(decoded, isNotNull);
    expect(decoded!.getPixel(800, 200).a, greaterThan(200));
    expect(decoded.getPixel(1500, 200).a, 0);
  });

  test('renders safely when GPS and address are unavailable', () async {
    final bytes = await VideoWatermarkOverlay.render(
      capturedAt: capturedAt,
      layout: 'classic',
    );

    final decoded = img.decodePng(bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 1600);
    expect(decoded.height, 260);
  });

  test('long address is rendered without failing overlay generation', () async {
    final bytes = await VideoWatermarkOverlay.render(
      capturedAt: capturedAt,
      latitude: -7.982612,
      longitude: 112.630812,
      accuracy: 8.5,
      address: 'Jalan Soekarno Hatta, Kelurahan Jatimulyo, Kecamatan Lowokwaru, '
          'Kota Malang, Provinsi Jawa Timur, Indonesia',
      layout: 'header',
    );

    expect(img.decodePng(bytes), isNotNull);
  });
}
