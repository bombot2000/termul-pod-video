import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_pod_video/services/pod_location_tracker.dart';

class _FakeBackend implements PodLocationBackend {
  PodLocationAvailability availability = PodLocationAvailability.ready;
  PodLocationSample? lastKnownSample;
  Completer<void>? availabilityGate;
  int positionsCalls = 0;
  final StreamController<PodLocationSample> controller =
      StreamController<PodLocationSample>.broadcast();

  @override
  Future<PodLocationAvailability> ensureAvailable() async {
    await availabilityGate?.future;
    return availability;
  }

  @override
  Stream<PodLocationSample> positions() {
    positionsCalls++;
    return controller.stream;
  }

  @override
  Future<PodLocationSample?> lastKnown() async => lastKnownSample;
}

void main() {
  final now = DateTime.utc(2026, 11, 14, 9, 30);

  PodLocationSample sample({
    int ageSeconds = 0,
    double accuracy = 8,
    bool mocked = false,
  }) {
    return PodLocationSample(
      latitude: -7.9826,
      longitude: 112.6308,
      accuracy: accuracy,
      timestamp: now.subtract(Duration(seconds: ageSeconds)),
      isMocked: mocked,
    );
  }

  late _FakeBackend backend;
  late PodLocationTracker tracker;

  setUp(() {
    backend = _FakeBackend();
    tracker = PodLocationTracker(backend: backend, clock: () => now);
  });

  tearDown(() async {
    tracker.dispose();
    await backend.controller.close();
  });

  Future<void> deliver(PodLocationSample value) async {
    backend.controller.add(value);
    await pumpEventQueue();
  }

  test('has no fix before the first reading', () async {
    await tracker.start();
    expect(tracker.latest, isNull);
    expect(tracker.status.value.state, PodLocationState.searching);
  });

  test('a live fix carries its age and updates the status', () async {
    await tracker.start();
    await deliver(sample(ageSeconds: 3));
    final fix = tracker.latest!;
    expect(fix.ageSeconds, 3);
    expect(fix.latitude, -7.9826);
    expect(fix.isPoor, isFalse);
    expect(tracker.status.value.state, PodLocationState.ready);
  });

  test('a stale sample cannot overwrite the latest fresh sample', () async {
    await tracker.start();
    await deliver(sample());
    await deliver(sample(ageSeconds: 45, accuracy: 40));
    expect(tracker.latest, isNotNull);
    expect(tracker.latest!.accuracy, 8);
    expect(tracker.status.value.fix!.accuracy, 8);
  });

  test('future-dated samples outside clock tolerance are ignored', () async {
    await tracker.start();
    await deliver(PodLocationSample(
      latitude: -7.9,
      longitude: 112.7,
      accuracy: 3,
      timestamp: now.add(const Duration(seconds: 10)),
    ));
    expect(tracker.latest, isNull);
  });

  test('out-of-order samples cannot replace the latest accepted fix',
      () async {
    await tracker.start();
    await deliver(sample());
    await deliver(sample(ageSeconds: 1, accuracy: 2));
    expect(tracker.latest!.accuracy, 8);
    expect(tracker.latest!.latitude, -7.9826);
  });

  test('smoothed coordinates retain raw platform accuracy', () async {
    await tracker.start();
    await deliver(sample(accuracy: 12));
    await deliver(PodLocationSample(
      latitude: -7.98261,
      longitude: 112.63081,
      accuracy: 17,
      timestamp: now.add(const Duration(seconds: 1)),
    ));
    expect(tracker.latest!.accuracy, 17);
    expect(tracker.latest!.rawLatitude, -7.98261);
    expect(tracker.latest!.sampleCount, 2);
  });

  test('invalid platform accuracy is treated as weak', () async {
    await tracker.start();
    await deliver(sample(accuracy: double.nan));
    expect(tracker.latest!.accuracy, podPoorAccuracyMeters + 1);
    expect(tracker.latest!.isPoor, isTrue);
  });

  test('weak accuracy and mock providers are flagged', () async {
    await tracker.start();
    await deliver(sample(accuracy: podPoorAccuracyMeters + 30, mocked: true));
    final fix = tracker.latest!;
    expect(fix.isPoor, isTrue);
    expect(fix.isMocked, isTrue);
  });

  test('start is idempotent', () async {
    await tracker.start();
    await tracker.start();
    expect(backend.positionsCalls, 1);
  });

  test('acquire returns a fresh live fix immediately', () async {
    await tracker.start();
    await deliver(sample(ageSeconds: 1));
    final fix = await tracker.acquire(wait: const Duration(milliseconds: 20));
    expect(fix, isNotNull);
    expect(fix!.ageSeconds, 1);
  });

  test('acquire waits for the next reading when none is available', () async {
    await tracker.start();
    final pending = tracker.acquire(wait: const Duration(seconds: 2));
    backend.controller.add(sample());
    final fix = await pending;
    expect(fix, isNotNull);
    expect(fix!.accuracy, 8);
  });

  test('acquire returns null on timeout without a last-known position',
      () async {
    await tracker.start();
    final fix = await tracker.acquire(wait: const Duration(milliseconds: 30));
    expect(fix, isNull);
  });

  test('acquire falls back to a recent last-known position', () async {
    backend.lastKnownSample = sample(ageSeconds: 60);
    await tracker.start();
    final fix = await tracker.acquire(wait: const Duration(milliseconds: 30));
    expect(fix, isNotNull);
    expect(fix!.ageSeconds, 60);
  });

  test('acquire rejects an old last-known position', () async {
    backend.lastKnownSample = sample(ageSeconds: 600);
    await tracker.start();
    final fix = await tracker.acquire(wait: const Duration(milliseconds: 30));
    expect(fix, isNull);
  });

  test('denied permission is reported and nothing is subscribed', () async {
    backend.availability = PodLocationAvailability.denied;
    await tracker.start();
    expect(tracker.status.value.state, PodLocationState.denied);
    expect(backend.controller.hasListener, isFalse);
    expect(
      await tracker.acquire(wait: const Duration(milliseconds: 30)),
      isNull,
    );
  });

  test('disabled location service is reported', () async {
    backend.availability = PodLocationAvailability.serviceDisabled;
    await tracker.start();
    expect(tracker.status.value.state, PodLocationState.serviceDisabled);
  });

  test('stop while permission is being requested wins', () async {
    final gate = Completer<void>();
    backend.availabilityGate = gate;
    final started = tracker.start();
    await tracker.stop();
    gate.complete();
    await started;
    expect(backend.controller.hasListener, isFalse);
    expect(tracker.status.value.state, PodLocationState.idle);
  });

  test('can start again after stop', () async {
    await tracker.start();
    await tracker.stop();
    expect(backend.controller.hasListener, isFalse);
    await tracker.start();
    expect(backend.controller.hasListener, isTrue);
  });

  group('device clock that disagrees with GPS time', () {
    late DateTime current;
    late PodLocationTracker skewed;

    setUp(() {
      current = now;
      skewed = PodLocationTracker(backend: backend, clock: () => current);
    });

    tearDown(() => skewed.dispose());

    PodLocationSample gpsSample(Duration gpsAhead) {
      return PodLocationSample(
        latitude: -7.9826,
        longitude: 112.6308,
        accuracy: 8,
        timestamp: current.add(gpsAhead),
      );
    }

    Future<void> push(PodLocationSample value) async {
      backend.controller.add(value);
      await pumpEventQueue();
    }

    test('a phone clock that is a minute behind still gets coordinates',
        () async {
      await skewed.start();
      const ahead = Duration(seconds: 60);

      await push(gpsSample(ahead));
      expect(skewed.latest, isNull);

      current = current.add(const Duration(seconds: 1));
      await push(gpsSample(ahead));
      final fix = skewed.latest!;
      expect(fix.ageSeconds, 0);
      expect(fix.clockOffsetSeconds, -60);

      current = current.add(const Duration(seconds: 1));
      await push(gpsSample(ahead));
      expect(skewed.latest!.sampleCount, 2);
    });

    test('a phone clock that is minutes ahead is corrected too', () async {
      await skewed.start();
      const behind = Duration(minutes: -5);

      await push(gpsSample(behind));
      current = current.add(const Duration(seconds: 1));
      await push(gpsSample(behind));

      expect(skewed.latest, isNotNull);
      expect(skewed.latest!.clockOffsetSeconds, 300);
    });

    test('a burst of old cached fixes is not mistaken for clock skew',
        () async {
      await skewed.start();
      await push(gpsSample(const Duration(minutes: -3)));
      await push(gpsSample(const Duration(seconds: -179)));
      await push(gpsSample(const Duration(seconds: -178)));
      expect(skewed.latest, isNull);
    });

    test('a corrected clock goes back to normal ageing', () async {
      await skewed.start();
      const ahead = Duration(seconds: 60);
      await push(gpsSample(ahead));
      current = current.add(const Duration(seconds: 1));
      await push(gpsSample(ahead));
      expect(skewed.latest!.clockOffsetSeconds, -60);

      // The phone syncs its clock: it jumps forward to GPS time, which has
      // itself kept running, so GPS timestamps stay in order.
      current = current.add(const Duration(seconds: 61));
      await push(gpsSample(Duration.zero));
      expect(skewed.latest!.clockOffsetSeconds, 0);
    });

    test('moving samples are passed through unsmoothed', () async {
      await skewed.start();
      await push(PodLocationSample(
        latitude: -7.9826,
        longitude: 112.6308,
        accuracy: 8,
        timestamp: current,
        speed: 0.1,
      ));
      current = current.add(const Duration(seconds: 1));
      await push(PodLocationSample(
        latitude: -7.98251,
        longitude: 112.6308,
        accuracy: 8,
        timestamp: current,
        speed: 12,
      ));

      final fix = skewed.latest!;
      expect(fix.latitude, -7.98251);
      expect(fix.sampleCount, 1);
    });
  });
}
