import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_pod_video/services/pod_location_tracker.dart';

class _FakeBackend implements PodLocationBackend {
  _FakeBackend({
    this.availability = PodLocationAvailability.ready,
    this.lastKnownSample,
    this.availabilityGate,
  });

  PodLocationAvailability availability;
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

  test('a fix older than maxFixAge is not used for a capture', () async {
    await tracker.start();
    await deliver(sample(ageSeconds: 45));
    expect(tracker.latest, isNull);
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

  test('acquire returns null on timeout without a last-known position', () async {
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
}
