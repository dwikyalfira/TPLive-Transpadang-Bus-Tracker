import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/features/tracking/data/corridor_route.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/domain/corridor_path.dart';

Halte _h(String nama, double lat, double lng) =>
    Halte(nama: nama, pos: LatLng(lat, lng));

HalteDataset _dataset() => HalteDataset({
      'K1': CorridorStops(kode: 'K1', arah: {
        'pergi': CorridorDirection(label: 'A - B', halte: [
          _h('A', -0.90, 100.30),
          _h('B', -0.91, 100.31),
          _h('C', -0.92, 100.32),
        ]),
        'pulang': CorridorDirection(label: 'C - A', halte: [
          _h('C', -0.92, 100.32),
          _h('A', -0.90, 100.30),
        ]),
      }),
      'K3': CorridorStops(kode: 'K3', arah: {
        'pergi': CorridorDirection(label: 'D - E', halte: [
          _h('D', -0.93, 100.33),
          _h('E', -0.94, 100.34),
        ]),
      }),
    });

void main() {
  test('membuat satu jalur per arah dengan titik urut', () {
    final paths = buildCorridorPaths(_dataset(), filterCorridor: 'K1');

    expect(paths.map((p) => p.corridor), ['K1', 'K1']);
    expect(paths.map((p) => p.directionKey), ['pergi', 'pulang']);

    final pergi = paths.firstWhere((p) => p.directionKey == 'pergi');
    expect(pergi.points, [
      const LatLng(-0.90, 100.30),
      const LatLng(-0.91, 100.31),
      const LatLng(-0.92, 100.32),
    ]);
  });

  test('menyaring per koridor (abaikan besar-kecil huruf)', () {
    final paths = buildCorridorPaths(_dataset(), filterCorridor: 'k3');

    expect(paths.map((p) => p.corridor), ['K3']);
    expect(paths.single.points, hasLength(2));
  });

  test('tanpa penyaring menyertakan semua koridor', () {
    final paths = buildCorridorPaths(_dataset());

    expect(paths.map((p) => p.corridor), ['K1', 'K1', 'K3']);
  });

  test('melewati arah dengan kurang dari dua halte', () {
    final dataset = HalteDataset({
      'K2': CorridorStops(kode: 'K2', arah: {
        'pergi': CorridorDirection(label: 'X', halte: [_h('X', -0.90, 100.30)]),
      }),
    });

    expect(buildCorridorPaths(dataset), isEmpty);
  });

  test('memakai geometri mengikuti jalan bila tersedia', () {
    const routed = CorridorRouteDataset({
      'K1': {
        'pergi': [
          LatLng(-0.90, 100.30),
          LatLng(-0.905, 100.305),
          LatLng(-0.91, 100.31),
          LatLng(-0.92, 100.32),
        ],
      },
    });

    final paths = buildCorridorPaths(
      _dataset(),
      filterCorridor: 'K1',
      routeGeometry: routed,
    );

    final pergi = paths.firstWhere((p) => p.directionKey == 'pergi');
    expect(pergi.points, hasLength(4));
    expect(pergi.points[1], const LatLng(-0.905, 100.305));
    // Arah tanpa geometri rute jatuh ke garis antar-halte.
    final pulang = paths.firstWhere((p) => p.directionKey == 'pulang');
    expect(pulang.points, hasLength(2));
  });

  test('jatuh ke garis antar-halte bila geometri rute kosong', () {
    final paths = buildCorridorPaths(
      _dataset(),
      filterCorridor: 'K1',
      routeGeometry: const CorridorRouteDataset({}),
    );

    final pergi = paths.firstWhere((p) => p.directionKey == 'pergi');
    expect(pergi.points, [
      const LatLng(-0.90, 100.30),
      const LatLng(-0.91, 100.31),
      const LatLng(-0.92, 100.32),
    ]);
  });
}
