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
