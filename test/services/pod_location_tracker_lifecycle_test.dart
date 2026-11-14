import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_pod_video/services/pod_location_tracker.dart';

class _FakeLocationBackend implements PodLocationBackend {
  _FakeLocationBackend(this.gate);

  final Completer<void> gate;
  final StreamController<PodLocationSample> controller =
      StreamController<PodLocationSample>.broadcast();
  int ensureCalls = 0;

  @override
  Future<PodLocationAvailability> ensureAvailable() async {
    ensureCalls++;
    await gate.future;
    return PodLocationAvailability.ready;
  }

  @override
  Stream<PodLocationSample> positions() => controller.stream;

  @override
  Future<PodLocationSample?> lastKnown() async => null;
}

void main() {
  late Completer<void> permissionGate;
  late _FakeLocationBackend backend;
  late PodLocationTracker tracker;
  final now = DateTime.utc(2026, 11, 14, 10);

  setUp(() {
    permissionGate = Completer<void>();
    backend = _FakeLocationBackend(permissionGate);
    tracker = PodLocationTracker(backend: backend, clock: () => now);
  });

  tearDown(() async {
    tracker.dispose();
    await backend.controller.close();
  });

  test('can restart after stop while permission request is still pending',
      () async {
    final firstStart = tracker.start();
    await Future<void>.delayed(Duration.zero);

    await tracker.stop();
    final secondStart = tracker.start();
    await Future<void>.delayed(Duration.zero);

    expect(backend.ensureCalls, 2);

    permissionGate.complete();
    await Future.wait([firstStart, secondStart]);

    expect(backend.controller.hasListener, isTrue);
    expect(tracker.status.value.state, PodLocationState.searching);
  });

  test('does not use an expired sample received while waiting for GPS',
      () async {
    final starting = tracker.start();
    await Future<void>.delayed(Duration.zero);
    permissionGate.complete();
    await starting;

    final pending = tracker.acquire(wait: const Duration(seconds: 1));
    backend.controller.add(
      PodLocationSample(
        latitude: -7.9826,
        longitude: 112.6308,
        accuracy: 5,
        timestamp: now.subtract(const Duration(minutes: 2)),
      ),
    );

    expect(await pending, isNull);
  });
}
