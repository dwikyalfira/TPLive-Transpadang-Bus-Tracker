import 'package:latlong2/latlong.dart';

import '../data/halte_data.dart';

/// Satu halte fisik di peta, hasil penggabungan entri dari kedua arah
/// (`pergi`/`pulang`) dan dari koridor mana pun yang melewatinya.
///
/// Data mentah `assets/halte.json` memuat halte yang sama beberapa kali (sisi
/// jalan berbeda). Menggabungkannya penting supaya peta tidak menggambar titik
/// dobel untuk satu halte.
class MapStop {
  /// Kunci stabil untuk widget/test, mis. `rth imam bonjol#3`.
  final String id;

  final String name;

  final LatLng pos;

  /// Kode koridor yang melayani halte ini, terurut (mis. `['K1', 'K4']`).
  final List<String> corridors;

  const MapStop({
    required this.id,
    required this.name,
    required this.pos,
    required this.corridors,
  });

  /// Benar bila halte dilayani lebih dari satu koridor (titik transit).
  bool get isInterchange => corridors.length > 1;
}

const Distance _distance = Distance();

/// Ambang jarak (meter) untuk menganggap dua entri sebagai halte fisik yang
/// sama. Koordinat arah `pergi`/`pulang` bisa terpaut beberapa puluh meter
/// karena berada di sisi jalan yang berbeda.
const double kMapStopMergeMeters = 30;

String _normKey(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Menggabungkan seluruh entri [dataset] menjadi daftar halte fisik unik.
///
/// Dua entri digabung bila **namanya sama** dan jaraknya <= [mergeMeters].
/// Nama sama tetapi berjauhan tetap dianggap halte berbeda supaya halte
/// senama di lokasi lain tidak ikut menyatu.
List<MapStop> buildMapStops(
  HalteDataset dataset, {
  double mergeMeters = kMapStopMergeMeters,
}) {
  final byName = <String, List<_Cluster>>{};
  final ordered = <_Cluster>[];

  final codes = dataset.corridors.keys.toList()..sort();
  for (final code in codes) {
    final stops = dataset.corridors[code];
    if (stops == null) continue;
    final directions = stops.arah.keys.toList()..sort();
    for (final direction in directions) {
      final halteList = stops.arah[direction]?.halte;
      if (halteList == null) continue;
      for (final halte in halteList) {
        final key = _normKey(halte.nama);
        final bucket = byName.putIfAbsent(key, () => <_Cluster>[]);
        _Cluster? match;
        for (final cluster in bucket) {
          if (_distance.as(LengthUnit.Meter, cluster.pos, halte.pos) <=
              mergeMeters) {
            match = cluster;
            break;
          }
        }
        if (match == null) {
          final cluster = _Cluster(key: key, name: halte.nama, pos: halte.pos)
            ..corridors.add(code);
          bucket.add(cluster);
          ordered.add(cluster);
        } else {
          match.corridors.add(code);
        }
      }
    }
  }

  return [
    for (var i = 0; i < ordered.length; i++)
      MapStop(
        id: '${ordered[i].key}#$i',
        name: ordered[i].name,
        pos: ordered[i].pos,
        corridors: ordered[i].corridors.toList()..sort(),
      ),
  ];
}

class _Cluster {
  final String key;
  final String name;
  final LatLng pos;
  final Set<String> corridors = <String>{};

  _Cluster({required this.key, required this.name, required this.pos});
}
