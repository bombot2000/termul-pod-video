import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Accuracy (metres) above which a fix is flagged as weak in the UI and history.
const double podPoorAccuracyMeters = 50;

enum PodLocationAvailability { ready, serviceDisabled, denied, deniedForever }

enum PodLocationState {
  idle,
  searching,
  ready,
  serviceDisabled,
  denied,
  deniedForever,
}

/// A raw position reading, independent of the geolocator plugin types.
class PodLocationSample {
  const PodLocationSample({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.isMocked = false,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final bool isMocked;
}

/// A reading together with how old it was when it was used.
class PodLocationFix {
  const PodLocationFix({required this.sample, required this.age});

  final PodLocationSample sample;
  final Duration age;

  double get latitude => sample.latitude;
  double get longitude => sample.longitude;
  double get accuracy => sample.accuracy;
  bool get isMocked => sample.isMocked;
  bool get isPoor => accuracy > podPoorAccuracyMeters;
  int get ageSeconds => age.isNegative ? 0 : age.inSeconds;
}

class PodLocationStatus {
  const PodLocationStatus(this.state, [this.fix]);

  final PodLocationState state;
  final PodLocationFix? fix;
}

abstract class PodLocationBackend {
  Future<PodLocationAvailability> ensureAvailable();
  Stream<PodLocationSample> positions();
  Future<PodLocationSample?> lastKnown();
}

class GeolocatorLocationBackend implements PodLocationBackend {
  @override
  Future<PodLocationAvailability> ensureAvailable() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return PodLocationAvailability.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return PodLocationAvailability.denied;
    }
    if (permission == LocationPermission.deniedForever) {
      return PodLocationAvailability.deniedForever;
    }
    return PodLocationAvailability.ready;
  }

  @override
  Stream<PodLocationSample> positions() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).map(_toSample);
  }

  @override
  Future<PodLocationSample?> lastKnown() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      return position == null ? null : _toSample(position);
    } catch (_) {
      return null;
    }
  }

  static PodLocationSample _toSample(Position position) {
    return PodLocationSample(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      isMocked: position.isMocked,
    );
  }
}

/// Keeps a live GPS fix while the camera screen is open, so a capture can use
/// the position at the moment of the shutter instead of waiting for GPS after
/// the picture has already been taken.
class PodLocationTracker {
  PodLocationTracker({
    PodLocationBackend? backend,
    DateTime Function()? clock,
    this.maxFixAge = const Duration(seconds: 30),
    this.maxLastKnownAge = const Duration(minutes: 5),
  })  : _backend = backend ?? GeolocatorLocationBackend(),
        _clock = clock ?? DateTime.now;

  final PodLocationBackend _backend;
  final DateTime Function() _clock;

  /// A live fix older than this is not used for a capture.
  final Duration maxFixAge;

  /// A cached "last known" position older than this is rejected.
  final Duration maxLastKnownAge;

  final ValueNotifier<PodLocationStatus> status =
      ValueNotifier<PodLocationStatus>(
    const PodLocationStatus(PodLocationState.idle),
  );

  final StreamController<PodLocationSample> _updates =
      StreamController<PodLocationSample>.broadcast();
  StreamSubscription<PodLocationSample>? _subscription;
  PodLocationSample? _latest;
  int _generation = 0;
  bool _starting = false;
  bool _disposed = false;

  PodLocationFix _fixFor(PodLocationSample sample) =>
      PodLocationFix(sample: sample, age: _clock().difference(sample.timestamp));

  /// The newest live fix, or null if there is none or it is too old.
  PodLocationFix? get latest {
    final sample = _latest;
    if (sample == null) return null;
    final fix = _fixFor(sample);
    return fix.age > maxFixAge ? null : fix;
  }

  /// Requests permission if needed and starts listening. Safe to call
  /// repeatedly. A [stop] issued while permission is being requested wins.
  Future<void> start() async {
    if (_disposed || _subscription != null || _starting) return;
    _starting = true;
    final generation = ++_generation;
    try {
      status.value = const PodLocationStatus(PodLocationState.searching);
      final availability = await _backend.ensureAvailable();
      if (_disposed || generation != _generation) return;
      switch (availability) {
        case PodLocationAvailability.serviceDisabled:
          status.value =
              const PodLocationStatus(PodLocationState.serviceDisabled);
          return;
        case PodLocationAvailability.denied:
          status.value = const PodLocationStatus(PodLocationState.denied);
          return;
        case PodLocationAvailability.deniedForever:
          status.value =
              const PodLocationStatus(PodLocationState.deniedForever);
          return;
        case PodLocationAvailability.ready:
          break;
      }
      _subscription = _backend.positions().listen(
        _onSample,
        onError: (Object _) {
          // Keep the last good fix; the stream may recover by itself.
        },
      );
    } catch (_) {
      if (!_disposed && generation == _generation) {
        status.value = const PodLocationStatus(PodLocationState.denied);
      }
    } finally {
      // A stopped start() may finish after a newer start() has begun.
      // Only the generation that still owns the startup may clear this flag.
      if (generation == _generation) _starting = false;
    }
  }

  void _onSample(PodLocationSample sample) {
    if (_disposed) return;
    _latest = sample;
    _updates.add(sample);
    status.value = PodLocationStatus(PodLocationState.ready, _fixFor(sample));
  }

  Future<void> stop() async {
    _generation++;
    // Allow a new start immediately; the previous permission request is
    // invalidated by the generation check above.
    _starting = false;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    if (!_disposed) {
      status.value = const PodLocationStatus(PodLocationState.idle);
    }
  }

  /// Returns a position for a capture. A fresh live fix is returned at once
  /// (synchronously up to the first await, so calling this at the moment of
  /// the shutter snapshots that moment). Otherwise it waits up to [wait] for
  /// the next reading, then falls back to a recent last-known position.
  Future<PodLocationFix?> acquire({
    Duration wait = const Duration(seconds: 4),
  }) async {
    final current = latest;
    if (current != null) return current;

    if (_subscription != null) {
      try {
        final sample = await _updates.stream.first.timeout(wait);
        final fix = _fixFor(sample);
        if (fix.age <= maxFixAge) return fix;
      } catch (_) {
        // Timed out or closed: fall through to the last-known position.
      }
    }

    final lastKnown = await _backend.lastKnown();
    if (lastKnown == null) return null;
    final fix = _fixFor(lastKnown);
    return fix.age > maxLastKnownAge ? null : fix;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    unawaited(_updates.close());
    status.dispose();
  }
}
