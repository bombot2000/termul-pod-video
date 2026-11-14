import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'pod_gps_engine.dart';

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

class PodLocationSample {
  const PodLocationSample({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.isMocked = false,
    this.rawLatitude,
    this.rawLongitude,
    this.sampleCount = 1,
    this.locked = false,
    this.speed,
  });

  /// Position used for the watermark and saved record.
  final double latitude;
  final double longitude;
  /// Android/geolocator horizontal accuracy for the current raw reading.
  final double accuracy;
  final DateTime timestamp;
  final bool isMocked;
  final double? rawLatitude;
  final double? rawLongitude;
  final int sampleCount;
  final bool locked;

  /// Reported ground speed in m/s, when the platform provides one.
  final double? speed;
}

class PodLocationFix {
  const PodLocationFix({
    required this.sample,
    required this.age,
    this.clockOffset = Duration.zero,
  });

  final PodLocationSample sample;
  final Duration age;

  /// How far the device clock is from GPS time (device minus GPS), when the
  /// tracker had to correct for it. Zero when the clock agrees with GPS.
  final Duration clockOffset;
  int get clockOffsetSeconds => clockOffset.inSeconds;

  double get latitude => sample.latitude;
  double get longitude => sample.longitude;
  double get accuracy => sample.accuracy;
  bool get isMocked => sample.isMocked;
  double get rawLatitude => sample.rawLatitude ?? sample.latitude;
  double get rawLongitude => sample.rawLongitude ?? sample.longitude;
  int get sampleCount => sample.sampleCount;
  bool get isLocked => sample.locked;
  bool get isPoor => accuracy > podPoorAccuracyMeters;
  int get ageSeconds => age.isNegative ? 0 : age.inSeconds;
}

class _SkewProbe {
  const _SkewProbe(this.timestamp, this.receivedAt);

  final DateTime timestamp;
  final DateTime receivedAt;
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
    final LocationSettings settings =
        defaultTargetPlatform == TargetPlatform.android
            ? AndroidSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 0,
                intervalDuration: const Duration(seconds: 1),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 0,
              );
    return Geolocator.getPositionStream(locationSettings: settings)
        .map(_toSample);
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
      speed: position.speed,
    );
  }
}

/// Keeps a live GPS fix warm while the camera screen is open.
class PodLocationTracker {
  PodLocationTracker({
    PodLocationBackend? backend,
    DateTime Function()? clock,
    PodGpsEngine? engine,
    this.maxFixAge = const Duration(seconds: 30),
    this.maxLastKnownAge = const Duration(minutes: 5),
    this.maxFutureSkew = const Duration(seconds: 5),
  })  : _backend = backend ?? GeolocatorLocationBackend(),
        _clock = clock ?? DateTime.now,
        _engine = engine ?? PodGpsEngine();

  final PodLocationBackend _backend;
  final DateTime Function() _clock;
  final PodGpsEngine _engine;
  final Duration maxFixAge;
  final Duration maxLastKnownAge;
  /// Small device-clock skew is tolerated; farther-future fixes are rejected.
  final Duration maxFutureSkew;

  final ValueNotifier<PodLocationStatus> status =
      ValueNotifier<PodLocationStatus>(
    const PodLocationStatus(PodLocationState.idle),
  );

  final StreamController<PodLocationSample> _updates =
      StreamController<PodLocationSample>.broadcast();
  StreamSubscription<PodLocationSample>? _subscription;
  PodLocationSample? _latest;
  DateTime? _lastAcceptedTimestamp;
  Duration _clockOffset = Duration.zero;
  _SkewProbe? _skewProbe;
  int _generation = 0;
  bool _starting = false;
  bool _disposed = false;

  PodLocationFix _fixFor(PodLocationSample sample) => PodLocationFix(
        sample: sample,
        age: _clock().difference(sample.timestamp) - _clockOffset,
        clockOffset: _clockOffset,
      );

  bool _isUsableLiveFix(PodLocationFix fix) =>
      fix.age <= maxFixAge && fix.age >= -maxFutureSkew;

  bool _isFreshAge(Duration age) => age <= maxFixAge && age >= -maxFutureSkew;

  /// Decides whether a sample is fresh enough, correcting for a device clock
  /// that disagrees with GPS time.
  ///
  /// GPS timestamps come from the satellites, the age check from the phone
  /// clock. If the phone clock is wrong, every fix looks stale or future-dated
  /// and the app would never get coordinates. Two consecutive out-of-range
  /// samples whose timestamps advance in step with their arrival are real
  /// readings on a skewed clock (a stale burst arrives all at once, so it
  /// does not match). The offset is then learned and applied.
  bool _acceptTimestamp(DateTime timestamp, DateTime received) {
    final rawAge = received.difference(timestamp);
    if (_isFreshAge(rawAge)) {
      _clockOffset = Duration.zero;
      _skewProbe = null;
      return true;
    }
    if (_clockOffset != Duration.zero && _isFreshAge(rawAge - _clockOffset)) {
      return true;
    }
    final probe = _skewProbe;
    _skewProbe = _SkewProbe(timestamp, received);
    if (probe == null) return false;
    final timestampStep = timestamp.difference(probe.timestamp);
    final arrivalStep = received.difference(probe.receivedAt);
    if (timestampStep < const Duration(milliseconds: 500) ||
        arrivalStep < const Duration(milliseconds: 500)) {
      return false;
    }
    if ((timestampStep - arrivalStep).abs() > const Duration(seconds: 1)) {
      return false;
    }
    _clockOffset = rawAge;
    _skewProbe = null;
    return true;
  }

  /// The newest live fix, or null if there is none or it is too old.
  PodLocationFix? get latest {
    final sample = _latest;
    if (sample == null) return null;
    final fix = _fixFor(sample);
    return _isUsableLiveFix(fix) ? fix : null;
  }

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
      if (generation == _generation) _starting = false;
    }
  }

  void _onSample(PodLocationSample raw) {
    if (_disposed) return;
    // Expired, future-dated, malformed and out-of-order events must not
    // replace a newer fix or contaminate the smoothing window.
    if (!raw.latitude.isFinite ||
        !raw.longitude.isFinite ||
        raw.latitude < -90 ||
        raw.latitude > 90 ||
        raw.longitude < -180 ||
        raw.longitude > 180) {
      return;
    }
    final previousTimestamp = _lastAcceptedTimestamp;
    if (previousTimestamp != null &&
        !raw.timestamp.isAfter(previousTimestamp)) {
      return;
    }
    if (!_acceptTimestamp(raw.timestamp, _clock())) return;

    final platformAccuracy = raw.accuracy.isFinite && raw.accuracy > 0
        ? raw.accuracy
        : podPoorAccuracyMeters + 1;
    final estimate = _engine.add(
      latitude: raw.latitude,
      longitude: raw.longitude,
      accuracy: platformAccuracy,
      timestamp: raw.timestamp,
      speed: raw.speed,
    );
    final sample = PodLocationSample(
      latitude: estimate.latitude,
      longitude: estimate.longitude,
      // Never display a statistically reduced estimate as device accuracy.
      accuracy: platformAccuracy,
      timestamp: raw.timestamp,
      isMocked: raw.isMocked,
      rawLatitude: raw.latitude,
      rawLongitude: raw.longitude,
      sampleCount: estimate.sampleCount,
      locked: estimate.locked,
      speed: raw.speed,
    );
    _lastAcceptedTimestamp = raw.timestamp;
    _latest = sample;
    _updates.add(sample);
    status.value = PodLocationStatus(PodLocationState.ready, _fixFor(sample));
  }

  Future<void> stop() async {
    _generation++;
    _starting = false;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    _engine.reset();
    _latest = null;
    _lastAcceptedTimestamp = null;
    _clockOffset = Duration.zero;
    _skewProbe = null;
    if (!_disposed) {
      status.value = const PodLocationStatus(PodLocationState.idle);
    }
  }

  Future<PodLocationFix?> acquire({
    Duration wait = const Duration(seconds: 4),
  }) async {
    final current = latest;
    if (current != null) return current;

    if (_subscription != null) {
      try {
        final sample = await _updates.stream
            .firstWhere((sample) => _isUsableLiveFix(_fixFor(sample)))
            .timeout(wait);
        return _fixFor(sample);
      } catch (_) {
        // Timed out or closed: fall through to last-known position.
      }
    }

    final lastKnown = await _backend.lastKnown();
    if (lastKnown == null) return null;
    final fix = _fixFor(lastKnown);
    final validCoordinates = lastKnown.latitude.isFinite &&
        lastKnown.longitude.isFinite &&
        lastKnown.latitude >= -90 &&
        lastKnown.latitude <= 90 &&
        lastKnown.longitude >= -180 &&
        lastKnown.longitude <= 180;
    return !validCoordinates ||
            fix.age > maxLastKnownAge ||
            fix.age < -maxFutureSkew
        ? null
        : fix;
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
