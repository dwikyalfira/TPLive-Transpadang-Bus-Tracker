import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// Satu halte dengan koordinatnya.
class Halte {
  /// Id stabil dari aset (`k3-pergi-01`), dipakai sebagai kunci timeline dan
  /// penanda peta agar tidak bergantung pada nama yang bisa berubah/duplikat.
  ///
  /// Kosong untuk data yang dibangun langsung di pengujian; pemakai harus
  /// memakai [stableId] yang jatuh ke nama + posisi bila [id] kosong.
  final String id;

  final String nama;
  final LatLng pos;

  const Halte({required this.nama, required this.pos, this.id = ''});

  /// Kunci yang selalu tersedia: [id] bila ada, jika tidak gabungan nama+posisi.
  String get stableId => id.isNotEmpty
      ? id
      : '$nama@${pos.latitude.toStringAsFixed(5)},${pos.longitude.toStringAsFixed(5)}';
}

/// Urutan halte untuk satu arah perjalanan (pergi/pulang).
class CorridorDirection {
  final String label;
  final List<Halte> halte;

  const CorridorDirection({required this.label, required this.halte});
}

/// Data halte satu koridor (dua arah).
class CorridorStops {
  final String kode;
  final Map<String, CorridorDirection> arah;

  const CorridorStops({required this.kode, required this.arah});

  CorridorDirection? get pergi => arah['pergi'];
  CorridorDirection? get pulang => arah['pulang'];
}

/// Seluruh dataset halte per koridor, dimuat dari `assets/halte.json`.
class HalteDataset {
  final Map<String, CorridorStops> corridors;

  const HalteDataset(this.corridors);

  CorridorStops? forCorridor(String corridor) =>
      corridors[corridor.trim().toUpperCase()];
}

/// Memuat dataset halte dari aset.
Future<HalteDataset> loadHalteDataset() async {
  final raw = await rootBundle.loadString('assets/halte.json');
  final map = json.decode(raw) as Map<String, dynamic>;
  final corridors = <String, CorridorStops>{};

  map.forEach((kode, value) {
    final arahMap =
        (value as Map<String, dynamic>)['arah'] as Map<String, dynamic>;
    final arah = <String, CorridorDirection>{};
    arahMap.forEach((dirKey, dirVal) {
      final v = dirVal as Map<String, dynamic>;
      final list = (v['halte'] as List).map((h) {
        final m = h as Map<String, dynamic>;
        return Halte(
          id: (m['id'] ?? '').toString(),
          nama: (m['nama'] ?? '').toString(),
          pos: LatLng(
            (m['lat'] as num).toDouble(),
            (m['lng'] as num).toDouble(),
          ),
        );
      }).toList(growable: false);
      arah[dirKey] = CorridorDirection(
        label: (v['label'] ?? '').toString(),
        halte: list,
      );
    });
    corridors[kode.trim().toUpperCase()] =
        CorridorStops(kode: kode, arah: arah);
  });

  return HalteDataset(corridors);
}
