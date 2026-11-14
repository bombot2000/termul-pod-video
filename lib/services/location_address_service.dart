import 'dart:math' as math;

import 'package:geocoding/geocoding.dart';

typedef ReverseGeocodeLookup = Future<List<Placemark>> Function(
  double latitude,
  double longitude,
);

class LocationAddressService {
  LocationAddressService({
    ReverseGeocodeLookup? reverseGeocode,
    this.timeout = const Duration(seconds: 6),
  }) : _reverseGeocode = reverseGeocode ?? _platformReverseGeocode;

  final ReverseGeocodeLookup _reverseGeocode;
  final Duration timeout;

  static Future<List<Placemark>> _platformReverseGeocode(
    double latitude,
    double longitude,
  ) {
    return placemarkFromCoordinates(latitude, longitude);
  }

  Future<String?> resolveAddress({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await _reverseGeocode(latitude, longitude)
          .timeout(timeout);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final candidates = <String?>[
        place.name,
        place.street,
        place.subLocality,
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
        place.postalCode,
        place.country,
      ];
      final parts = <String>[];
      final seen = <String>{};
      for (final candidate in candidates) {
        final value = candidate?.trim();
        if (value == null || value.isEmpty) continue;
        if (seen.add(value.toLowerCase())) parts.add(value);
      }
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }
}

/// Great-circle distance in metres between two coordinates (haversine).
double distanceBetweenMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadius = 6371000.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Reuses the last resolved address for captures taken close together, which
/// keeps repeated photos at one stop fast and works when the network drops.
class CachedAddressResolver {
  CachedAddressResolver({
    LocationAddressService? service,
    this.reuseRadiusMeters = 30,
  }) : _service = service ??
            LocationAddressService(timeout: const Duration(seconds: 3));

  final LocationAddressService _service;
  final double reuseRadiusMeters;

  double? _latitude;
  double? _longitude;
  String? _address;

  Future<String?> resolve({
    required double latitude,
    required double longitude,
  }) async {
    final cachedLatitude = _latitude;
    final cachedLongitude = _longitude;
    final cachedAddress = _address;
    if (cachedAddress != null &&
        cachedLatitude != null &&
        cachedLongitude != null &&
        distanceBetweenMeters(
              cachedLatitude,
              cachedLongitude,
              latitude,
              longitude,
            ) <=
            reuseRadiusMeters) {
      return cachedAddress;
    }

    final resolved = await _service.resolveAddress(
      latitude: latitude,
      longitude: longitude,
    );
    if (resolved != null) {
      _latitude = latitude;
      _longitude = longitude;
      _address = resolved;
    }
    return resolved;
  }
}
