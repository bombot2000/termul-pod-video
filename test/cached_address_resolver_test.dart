import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:termul_pod_video/services/location_address_service.dart';

void main() {
  late int calls;

  CachedAddressResolver build({bool empty = false}) {
    calls = 0;
    return CachedAddressResolver(
      service: LocationAddressService(
        reverseGeocode: (_, __) async {
          calls++;
          if (empty) return <Placemark>[];
          return [Placemark(street: 'Jl. Contoh $calls')];
        },
      ),
    );
  }

  test('reuses the address for captures taken close together', () async {
    final resolver = build();

    final first =
        await resolver.resolve(latitude: -7.9826, longitude: 112.6308);
    final second =
        await resolver.resolve(latitude: -7.98261, longitude: 112.63081);

    expect(second, first);
    expect(calls, 1);
  });

  test('resolves again once the position has moved on', () async {
    final resolver = build();

    await resolver.resolve(latitude: -7.9826, longitude: 112.6308);
    final moved =
        await resolver.resolve(latitude: -7.9836, longitude: 112.6308);

    expect(moved, 'Jl. Contoh 2');
    expect(calls, 2);
  });

  test('a failed lookup is not cached', () async {
    final resolver = build(empty: true);

    expect(
      await resolver.resolve(latitude: -7.9826, longitude: 112.6308),
      isNull,
    );
    expect(
      await resolver.resolve(latitude: -7.9826, longitude: 112.6308),
      isNull,
    );
    expect(calls, 2);
  });

  test('distanceBetweenMeters is accurate enough for the reuse radius', () {
    expect(distanceBetweenMeters(10, 20, 10, 20), 0);
    expect(distanceBetweenMeters(0, 0, 0, 1), closeTo(111195, 200));
  });
}
