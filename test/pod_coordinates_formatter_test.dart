import 'package:flutter_test/flutter_test.dart';
import 'package:termul_pod_video/main.dart';

void main() {
  group('formatPodCoordinates', () {
    test('returns unavailable when latitude is missing', () {
      expect(
        formatPodCoordinates(null, 112.6308),
        'Koordinat GPS tidak tersedia',
      );
    });

    test('returns unavailable when longitude is missing', () {
      expect(
        formatPodCoordinates(-7.9826, null),
        'Koordinat GPS tidak tersedia',
      );
    });

    test('formats coordinates when both values are available', () {
      expect(
        formatPodCoordinates(-7.9826, 112.6308),
        '-7.982600, 112.630800',
      );
    });
  });
}
