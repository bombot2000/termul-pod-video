import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:termul_pod_video/services/location_address_service.dart';

void main() {
  test('combines useful placemark fields without duplicates', () async {
    final service = LocationAddressService(
      reverseGeocode: (_, __) async => [
        Placemark(
          name: 'Jl. Merdeka',
          street: 'Jl. Merdeka',
          subLocality: 'Klojen',
          locality: 'Malang',
          administrativeArea: 'Jawa Timur',
          country: 'Indonesia',
        ),
      ],
    );

    final address = await service.resolveAddress(
      latitude: -7.9826,
      longitude: 112.6308,
    );

    expect(address, 'Jl. Merdeka, Klojen, Malang, Jawa Timur, Indonesia');
  });

  test('returns null when geocoder has no result', () async {
    final service = LocationAddressService(
      reverseGeocode: (_, __) async => [],
    );

    expect(
      await service.resolveAddress(latitude: -7.9, longitude: 112.6),
      isNull,
    );
  });

  test('returns null when geocoding fails', () async {
    final service = LocationAddressService(
      reverseGeocode: (_, __) async => throw StateError('offline'),
    );

    expect(
      await service.resolveAddress(latitude: -7.9, longitude: 112.6),
      isNull,
    );
  });

  test('times out rather than blocking media save', () async {
    final service = LocationAddressService(
      reverseGeocode: (_, __) => Completer<List<Placemark>>().future,
      timeout: const Duration(milliseconds: 1),
    );

    expect(
      await service.resolveAddress(latitude: -7.9, longitude: 112.6),
      isNull,
    );
  });
}
