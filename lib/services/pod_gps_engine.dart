import 'dart:math' as math;

/// Tuning values are starting points and must be checked on real devices.
class PodGpsConfig {
  const PodGpsConfig({
    this.samplesBeforeLock = 3,
    this.lockAccuracyMeters = 20,
    this.windowSize = 8,
    this.windowMaxAge = const Duration(seconds: 20),
    this.moveThresholdMeters = 15,
    this.centroidWeight = 0.6,
    this.kalmanAccelNoise = 1.0,
    this.fallbackAccuracyMeters = 50,
  });

  final int samplesBeforeLock;
  final double lockAccuracyMeters;
  final int windowSize;
  final Duration windowMaxAge;
  final double moveThresholdMeters;
  final double centroidWeight;
  final double kalmanAccelNoise;
  final double fallbackAccuracyMeters;
}

class PodGpsEstimate {
  const PodGpsEstimate({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.sampleCount,
    required this.locked,
  });

  final double latitude;
  final double longitude;
  /// Conservative worst accuracy in the current smoothing window.
  final double accuracy;
  final int sampleCount;
  /// True only when enough samples meet the configured raw-accuracy gate.
  final bool locked;
}

class _Observation {
  const _Observation(this.x, this.y, this.weight, this.accuracy, this.time);

  final double x;
  final double y;
  final double weight;
  final double accuracy;
  final DateTime time;
}

/// Smooths small stationary GPS jitter while resetting promptly on movement.
/// Accuracy is never improved by averaging correlated GPS measurements.
class PodGpsEngine {
  PodGpsEngine({this.config = const PodGpsConfig()});

  final PodGpsConfig config;
  final List<_Observation> _window = <_Observation>[];
  _KalmanAxis? _kx;
  _KalmanAxis? _ky;
  double _lat0 = 0;
  double _lon0 = 0;
  double _cosLat = 1;
  DateTime? _lastAt;
  double? _estLat;
  double? _estLon;
  double _worstWindowAccuracy = double.infinity;

  static const double _metersPerDegLat = 110574;
  static const double _metersPerDegLon = 111320;

  void reset() {
    _window.clear();
    _kx = null;
    _ky = null;
    _lastAt = null;
    _estLat = null;
    _estLon = null;
    _worstWindowAccuracy = double.infinity;
  }

  double _toX(double lon) => (lon - _lon0) * _metersPerDegLon * _cosLat;
  double _toY(double lat) => (lat - _lat0) * _metersPerDegLat;
  double _toLon(double x) => _lon0 + x / (_metersPerDegLon * _cosLat);
  double _toLat(double y) => _lat0 + y / _metersPerDegLat;

  PodGpsEstimate add({
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime timestamp,
  }) {
    final acc = accuracy.isFinite && accuracy > 0
        ? accuracy
        : config.fallbackAccuracyMeters;

    final lastAccepted = _lastAt;
    if (lastAccepted != null && !timestamp.isAfter(lastAccepted)) {
      return PodGpsEstimate(
        latitude: _estLat ?? latitude,
        longitude: _estLon ?? longitude,
        accuracy: acc,
        sampleCount: _window.length,
        locked: _window.length >= config.samplesBeforeLock &&
            _worstWindowAccuracy <= config.lockAccuracyMeters,
      );
    }

    final estLat = _estLat;
    final estLon = _estLon;
    if (estLat != null && estLon != null) {
      final dx = (longitude - estLon) * _metersPerDegLon * _cosLat;
      final dy = (latitude - estLat) * _metersPerDegLat;
      final moved = math.sqrt(dx * dx + dy * dy);
      // Cap the accuracy-dependent gate so weak GPS cannot mask real travel.
      final movementGate = math.max(
        config.moveThresholdMeters,
        math.min(acc, config.moveThresholdMeters * 2),
      );
      if (moved > movementGate) reset();
    }

    if (_window.isEmpty) {
      _lat0 = latitude;
      _lon0 = longitude;
      _cosLat = math.max(math.cos(latitude * math.pi / 180), 0.01);
      _lastAt = timestamp;
      _kx = _KalmanAxis(0, acc);
      _ky = _KalmanAxis(0, acc);
    } else {
      final last = _lastAt ?? timestamp;
      final dt = (timestamp.difference(last).inMilliseconds / 1000)
          .clamp(0.0, 10.0)
          .toDouble();
      _kx!.predict(dt, config.kalmanAccelNoise);
      _ky!.predict(dt, config.kalmanAccelNoise);
      _lastAt = timestamp;
    }

    final x = _toX(longitude);
    final y = _toY(latitude);
    _kx!.update(x, acc);
    _ky!.update(y, acc);

    _window.add(_Observation(x, y, 1 / (acc * acc), acc, timestamp));
    while (_window.length > config.windowSize) {
      _window.removeAt(0);
    }
    _window.removeWhere(
      (observation) =>
          timestamp.difference(observation.time) > config.windowMaxAge,
    );

    final count = _window.length;
    _worstWindowAccuracy = _window.fold<double>(
      0,
      (worst, observation) => math.max(worst, observation.accuracy),
    );

    final double outLat;
    final double outLon;
    if (count <= 1) {
      outLat = latitude;
      outLon = longitude;
    } else {
      var sumW = 0.0;
      var cx = 0.0;
      var cy = 0.0;
      for (final observation in _window) {
        sumW += observation.weight;
        cx += observation.x * observation.weight;
        cy += observation.y * observation.weight;
      }
      cx /= sumW;
      cy /= sumW;
      final weight = config.centroidWeight;
      final blendX = weight * cx + (1 - weight) * _kx!.pos;
      final blendY = weight * cy + (1 - weight) * _ky!.pos;
      outLat = _toLat(blendY);
      outLon = _toLon(blendX);
    }

    _estLat = outLat;
    _estLon = outLon;

    final locked = count >= config.samplesBeforeLock &&
        _worstWindowAccuracy <= config.lockAccuracyMeters;
    return PodGpsEstimate(
      latitude: outLat,
      longitude: outLon,
      accuracy: _worstWindowAccuracy,
      sampleCount: count,
      locked: locked,
    );
  }
}

class _KalmanAxis {
  _KalmanAxis(this.pos, double accuracy)
      : vel = 0,
        p00 = accuracy * accuracy,
        p01 = 0,
        p10 = 0,
        p11 = 10;

  double pos;
  double vel;
  double p00;
  double p01;
  double p10;
  double p11;

  void predict(double dt, double accelNoise) {
    if (dt <= 0) return;
    final q = accelNoise * accelNoise;
    final q00 = q * dt * dt * dt * dt / 4;
    final q01 = q * dt * dt * dt / 2;
    final q11 = q * dt * dt;
    pos += vel * dt;
    final n00 = p00 + dt * (p10 + p01) + dt * dt * p11 + q00;
    final n01 = p01 + dt * p11 + q01;
    final n10 = p10 + dt * p11 + q01;
    final n11 = p11 + q11;
    p00 = n00;
    p01 = n01;
    p10 = n10;
    p11 = n11;
  }

  void update(double measurement, double accuracy) {
    final r = accuracy * accuracy;
    final s = p00 + r;
    final k0 = p00 / s;
    final k1 = p10 / s;
    final residual = measurement - pos;
    pos += k0 * residual;
    vel += k1 * residual;
    final n00 = p00 - k0 * p00;
    final n01 = p01 - k0 * p01;
    final n10 = p10 - k1 * p00;
    final n11 = p11 - k1 * p01;
    p00 = n00;
    p01 = n01;
    p10 = n10;
    p11 = n11;
  }
}
