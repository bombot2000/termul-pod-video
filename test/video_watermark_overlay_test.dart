import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:termul_pod_video/services/video_watermark_service.dart';

void main() {
  final capturedAt = DateTime(2026, 11, 15, 9, 30, 0);

  bool hasVisibleText(
    img.Image image, {
    required int left,
    required int top,
    required int right,
    required int bottom,
  }) {
    var visiblePixels = 0;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final pixel = image.getPixel(x, y);
        if (pixel.r > 70 || pixel.g > 80 || pixel.b > 75) {
          visiblePixels++;
          if (visiblePixels >= 12) return true;
        }
      }
    }
    return false;
  }

  test('renders visible timestamp and address text in every layout', () async {
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
          reason: 'panel center should be opaque: $layout');

      final timestampTop = switch (layout) {
        'compact' => 48,
        'header' => 56,
        _ => 60,
      };
      final addressTop = switch (layout) {
        'compact' => 178,
        'header' => 190,
        _ => 194,
      };
      final panelRight = layout == 'compact' ? 1132 : 1552;

      expect(
        hasVisibleText(
          decoded,
          left: 48,
          top: timestampTop,
          right: panelRight,
          bottom: timestampTop + 42,
        ),
        isTrue,
        reason: 'timestamp text should be visible in $layout',
      );
      expect(
        hasVisibleText(
          decoded,
          left: 48,
          top: addressTop,
          right: panelRight,
          bottom: 260,
        ),
        isTrue,
        reason: 'address text should be visible in $layout',
      );
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

  test('renders visible fallback labels when GPS and address are unavailable',
      () async {
    final bytes = await VideoWatermarkOverlay.render(
      capturedAt: capturedAt,
      layout: 'classic',
    );

    final decoded = img.decodePng(bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 1600);
    expect(decoded.height, 260);
    expect(
      hasVisibleText(decoded, left: 48, top: 112, right: 1552, bottom: 152),
      isTrue,
      reason: 'GPS fallback label should be visible',
    );
    expect(
      hasVisibleText(decoded, left: 48, top: 194, right: 1552, bottom: 260),
      isTrue,
      reason: 'address fallback label should be visible',
    );
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

    final decoded = img.decodePng(bytes);
    expect(decoded, isNotNull);
    expect(
      hasVisibleText(decoded!, left: 48, top: 190, right: 1552, bottom: 260),
      isTrue,
      reason: 'long address should leave visible glyphs in the address region',
    );
  });
}
