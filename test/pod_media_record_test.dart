import 'package:flutter_test/flutter_test.dart';
import 'package:termul_pod_video/models/pod_media_record.dart';

void main() {
  test('POD media record preserves timestamp and GPS metadata', () {
    final createdAt = DateTime.parse('2026-11-14T09:30:00.000');
    final original = PodMediaRecord(
      path: '/private/pod_media/pod_test.jpg',
      type: 'photo',
      createdAt: createdAt,
      latitude: -7.9826,
      longitude: 112.6308,
      accuracy: 8.5,
    );

    final restored = PodMediaRecord.fromJson(original.toJson());

    expect(restored.path, original.path);
    expect(restored.type, original.type);
    expect(restored.createdAt, createdAt);
    expect(restored.latitude, -7.9826);
    expect(restored.longitude, 112.6308);
    expect(restored.accuracy, 8.5);
  });

  test('POD media record supports capture without GPS permission', () {
    final original = PodMediaRecord(
      path: '/private/pod_media/pod_no_gps.jpg',
      type: 'photo',
      createdAt: DateTime.parse('2026-11-14T09:30:00.000'),
    );

    final restored = PodMediaRecord.fromJson(original.toJson());

    expect(restored.latitude, isNull);
    expect(restored.longitude, isNull);
    expect(restored.accuracy, isNull);
  });
}
