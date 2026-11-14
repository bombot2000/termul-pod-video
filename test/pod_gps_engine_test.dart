import 'package:flutter_test/flutter_test.dart';
import 'package:termul_pod_video/services/pod_gps_engine.dart';

void main() {
  const lat = -7.9826;
  const lon = 112.6308;
  final t0 = DateTime.utc(2026, 11, 14, 9);

  PodGpsEstimate feed(
    PodGpsEngine engine,
    int second, {
    double dLat = 0,
    double dLon = 0,
    double accuracy = 8,
    double? speed,
  }) {
    return engine.add(
      latitude: lat + dLat,
      longitude: lon + dLon,
      accuracy: accuracy,
      timestamp: t0.add(Duration(seconds: second)),
      speed: speed,
    );
  }

  test('a single sample is reported exactly as received', () {
    final engine = PodGpsEngine();
    final estimate = feed(engine, 0, accuracy: 12);
    expect(estimate.latitude, lat);
    expect(estimate.longitude, lon);
    expect(estimate.accuracy, 12);
    expect(estimate.sampleCount, 1);
    expect(estimate.locked, isFalse);
  });

  test('noisy readings from one spot are pulled toward the centre and lock',
      () {
    final engine = PodGpsEngine();
    const noise = 0.00002;
    late PodGpsEstimate estimate;
    for (var i = 0; i < 4; i++) {
      estimate = feed(engine, i, dLat: i.isEven ? noise : -noise);
    }
    expect((estimate.latitude - lat).abs(), lessThan(noise));
    expect(estimate.sampleCount, 4);
    expect(estimate.locked, isTrue);
    expect(estimate.accuracy, 8);
  });

  test('weak readings do not lock early', () {
    final engine = PodGpsEngine();
    late PodGpsEstimate estimate;
    for (var i = 0; i < 3; i++) {
      estimate = feed(engine, i, accuracy: 40);
    }
    expect(estimate.locked, isFalse);
  });

  test('weak readings never lock merely because time has passed', () {
    final engine = PodGpsEngine();
    late PodGpsEstimate estimate;
    for (var i = 0; i <= 20; i++) {
      estimate = feed(engine, i, accuracy: 40);
    }
    expect(estimate.locked, isFalse);
  });

  test('a large jump restarts smoothing and follows the real position', () {
    final engine = PodGpsEngine();
    for (var i = 0; i < 4; i++) {
      feed(engine, i);
    }
    const jump = 0.0009;
    final estimate = feed(engine, 4, dLat: jump);
    expect(estimate.latitude, lat + jump);
    expect(estimate.sampleCount, 1);
    expect(estimate.locked, isFalse);
  });

  test('long GPS gaps reset the old smoothing window', () {
    final engine = PodGpsEngine();
    for (var i = 0; i < 4; i++) {
      feed(engine, i);
    }
    final estimate = feed(engine, 30, dLat: 0.00005);
    expect(estimate.sampleCount, 1);
    expect(estimate.latitude, lat + 0.00005);
    expect(estimate.locked, isFalse);
  });

  test('reset forgets earlier readings', () {
    final engine = PodGpsEngine();
    for (var i = 0; i < 4; i++) {
      feed(engine, i);
    }
    engine.reset();
    expect(feed(engine, 5).sampleCount, 1);
  });

  test('out-of-order timestamp does not add another observation', () {
    final engine = PodGpsEngine();
    feed(engine, 2);
    final estimate = engine.add(
      latitude: lat + 0.001,
      longitude: lon + 0.001,
      accuracy: 5,
      timestamp: t0.add(const Duration(seconds: 1)),
    );
    expect(estimate.sampleCount, 1);
    expect(estimate.latitude, lat);
    expect(estimate.longitude, lon);
  });

  test('a moving user gets the raw reading with no smoothing lag', () {
    final engine = PodGpsEngine();
    for (var i = 0; i < 4; i++) {
      feed(engine, i, speed: 0.2);
    }
    // 10 m/s along the road, 10 m (about 0.00009 deg) per second.
    late PodGpsEstimate estimate;
    for (var i = 4; i < 8; i++) {
      estimate = feed(engine, i, dLat: 0.00009 * (i - 3), speed: 10);
      expect(estimate.latitude, lat + 0.00009 * (i - 3));
      expect(estimate.sampleCount, 1);
    }
  });

  test('smoothing resumes once the user stops again', () {
    final engine = PodGpsEngine();
    feed(engine, 0, speed: 0.1);
    feed(engine, 1, speed: 0.1);
    expect(feed(engine, 2, speed: 10).sampleCount, 1);
    feed(engine, 3, speed: 0.1);
    final estimate = feed(engine, 4, speed: 0.1);
    expect(estimate.sampleCount, 3);
  });

  test('walking pace below the threshold is still smoothed', () {
    final engine = PodGpsEngine();
    late PodGpsEstimate estimate;
    for (var i = 0; i < 3; i++) {
      estimate = feed(engine, i, speed: 0.6);
    }
    expect(estimate.sampleCount, 3);
  });
}
