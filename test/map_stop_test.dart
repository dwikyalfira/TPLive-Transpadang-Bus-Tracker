import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/domain/map_stop.dart';

Halte _h(double lat, double lng, String nama) =>
    Halte(nama: nama, pos: LatLng(lat, lng));

HalteDataset _dataset(Map<String, Map<String, List<Halte>>> corridors) {
  final result = <String, CorridorStops>{};
  corridors.forEach((kode, arah) {
    result[kode] = CorridorStops(
      kode: kode,
      arah: {
        for (final entry in arah.entries)
          entry.key: CorridorDirection(label: entry.key, halte: entry.value),
      },
    );
  });
  return HalteDataset(result);
}

void main() {
  test('menggabungkan halte pergi & pulang yang senama dan berdekatan', () {
    final dataset = _dataset({
      'K1': {
        'pergi': [_h(-0.90, 100.30, 'RTH Imam Bonjol')],
        // Sisi jalan seberang: ~11 m dari arah pergi.
        'pulang': [_h(-0.9001, 100.30, 'RTH Imam Bonjol')],
      },
    });

    final stops = buildMapStops(dataset);

    expect(stops, hasLength(1));
    expect(stops.single.name, 'RTH Imam Bonjol');
    expect(stops.single.corridors, ['K1']);
    expect(stops.single.isInterchange, isFalse);
  });

  test('tidak menggabungkan nama berbeda walau koordinatnya sama', () {
    final dataset = _dataset({
      'K1': {
        'pergi': [
          _h(-0.90, 100.30, 'Halte A'),
          _h(-0.90, 100.30, 'Halte B'),
        ],
      },
    });

    expect(buildMapStops(dataset), hasLength(2));
  });

  test('tidak menggabungkan nama sama yang berjauhan', () {
    final dataset = _dataset({
      'K1': {
        'pergi': [
          _h(-0.90, 100.30, 'Simpang'),
          // ~1,1 km dari entri pertama: halte lain dengan nama sama.
          _h(-0.91, 100.30, 'Simpang'),
        ],
      },
    });

    final stops = buildMapStops(dataset);
    expect(stops, hasLength(2));
    expect(stops.map((s) => s.id).toSet(), hasLength(2));
  });

  test('menggabungkan halte transit lintas koridor & menandainya', () {
    final dataset = _dataset({
      'K1': {
        'pergi': [_h(-0.90, 100.30, 'Pasar Raya')],
      },
      'K4': {
        'pulang': [_h(-0.9002, 100.3001, 'Pasar Raya')],
      },
    });

    final stops = buildMapStops(dataset);

    expect(stops, hasLength(1));
    expect(stops.single.corridors, ['K1', 'K4']);
    expect(stops.single.isInterchange, isTrue);
  });

  test('id tiap halte unik dan urut per koridor', () {
    final dataset = _dataset({
      'K1': {
        'pergi': [
          _h(-0.90, 100.30, 'A'),
          _h(-0.90, 100.31, 'B'),
        ],
      },
      'K3': {
        'pergi': [_h(-0.91, 100.32, 'C')],
      },
    });

    final stops = buildMapStops(dataset);

    expect(stops, hasLength(3));
    expect(stops.map((s) => s.id).toSet(), hasLength(3));
    expect(stops.map((s) => s.name), ['A', 'B', 'C']);
  });

  test('dataset kosong menghasilkan daftar kosong', () {
    expect(buildMapStops(const HalteDataset({})), isEmpty);
  });
}
