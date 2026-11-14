import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:termul_pod_video/services/video_watermark_service.dart';

void main() {
  test('renders a transparent PNG overlay with timestamp and POD details', () async {
    final bytes = await VideoWatermarkOverlay.render(
      capturedAt: DateTime.parse('2026-11-14T09:30:00'),
      latitude: -7.9826,
      longitude: 112.6308,
      accuracy: 8.5,
      address: 'Jl. Merdeka, Malang, Jawa Timur',
    );

    final decoded = img.decodePng(bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 1600);
    expect(decoded.height, 260);
    final panelPixel = decoded.getPixel(800, 130);
    expect(panelPixel.a, greaterThan(200));
    expect(panelPixel.r, lessThan(40));
    expect(panelPixel.g, lessThan(50));
  });

  test('renders watermark when GPS and address are unavailable', () async {
    final bytes = await VideoWatermarkOverlay.render(
      capturedAt: DateTime.parse('2026-11-14T09:30:00'),
    );

    final decoded = img.decodePng(bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 1600);
  });

  test('handles long addresses without overflowing the watermark canvas', () async {
    final bytes = await VideoWatermarkOverlay.render(
      capturedAt: DateTime.parse('2026-11-14T09:30:00'),
      address: 'Jalan yang sangat panjang dengan banyak keterangan lokasi '
          'dan kecamatan serta kabupaten di wilayah Jawa Timur Indonesia',
    );

    final decoded = img.decodePng(bytes);
    expect(decoded, isNotNull);
    expect(decoded!.height, 260);
  });
}
