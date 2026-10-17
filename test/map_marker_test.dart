import 'package:flutter_test/flutter_test.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/domain/map_marker.dart';

Bus _bus(
  String number,
  String corridor, {
  double? heading,
  Duration? age,
}) =>
    Bus(
      number: number,
      lat: -0.90,
      lng: 100.30,
      corridor: corridor,
      route: 'A - B',
      heading: heading,
      speedKmh: 20,
      lastUpdate: age == null ? null : DateTime.now().toUtc().subtract(age),
    );

void main() {
  final now = DateTime.now().toUtc();

  test('menyertakan semua bus yang masih segar', () {
    final markers = buildBusMapMarkers(
      [
        _bus('11', 'K1', age: const Duration(minutes: 1)),
        _bus('57', 'K3', age: const Duration(minutes: 2)),
      ],
      nowUtc: now,
    );

    expect(markers.map((m) => m.number), ['11', '57']);
    expect(markers.map((m) => m.corridor), ['K1', 'K3']);
  });

  test('membuang bus yang datanya basi (> 5 menit)', () {
    final markers = buildBusMapMarkers(
      [
        _bus('11', 'K1', age: const Duration(minutes: 1)),
        _bus('57', 'K3', age: const Duration(minutes: 10)),
      ],
      nowUtc: now,
    );

    expect(markers.map((m) => m.number), ['11']);
  });

  test('bus tanpa waktu update tetap disertakan', () {
    final markers = buildBusMapMarkers([_bus('11', 'K1')], nowUtc: now);

    expect(markers, hasLength(1));
  });

  test('menyaring per koridor (abaikan besar-kecil huruf)', () {
    final markers = buildBusMapMarkers(
      [
        _bus('11', 'K1', age: const Duration(minutes: 1)),
        _bus('57', 'K3', age: const Duration(minutes: 1)),
      ],
      filterCorridor: 'k3',
      nowUtc: now,
    );

    expect(markers.map((m) => m.corridor), ['K3']);
  });

  test('menormalkan arah: hanya 0..<360 yang dipakai', () {
    final markers = buildBusMapMarkers(
      [
        _bus('a', 'K1', heading: 90, age: const Duration(minutes: 1)),
        _bus('b', 'K1', heading: 360, age: const Duration(minutes: 1)),
        _bus('c', 'K1', heading: -1, age: const Duration(minutes: 1)),
        _bus('d', 'K1', age: const Duration(minutes: 1)),
      ],
      nowUtc: now,
    );

    final byNumber = {for (final m in markers) m.number: m.heading};
    expect(byNumber['a'], 90);
    expect(byNumber['b'], isNull);
    expect(byNumber['c'], isNull);
    expect(byNumber['d'], isNull);
  });
}
