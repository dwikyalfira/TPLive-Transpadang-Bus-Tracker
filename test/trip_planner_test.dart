import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/core/config.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/trip/domain/trip_planner.dart';

int? _firstIndex(List<Halte> halte, String name) {
  for (var i = 0; i < halte.length; i++) {
    if (halte[i].nama.toLowerCase() == name.toLowerCase()) return i;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rute langsung halte→halte dipilih walau koordinat halte antar koridor '
      'berbeda', () async {
    final ds = await loadHalteDataset();

    Halte find(String name, String kode, String key) {
      final c = ds.corridors[kode]!;
      return c.arah[key]!.halte.firstWhere(
          (h) => h.nama.toLowerCase() == name.toLowerCase());
    }

    // Kasus nyata: TK Aisyiah Lolongkaran → Masjid Raya Sumbar. Arah K3
    // "pulang" melewati Masjid Raya; koordinat halte bernama sama di K1/K3
    // berbeda puluhan meter karena berada di sisi jalan yang berbeda.
    final origin = find('TK Aisyiah/Lolongkaran', 'K3', 'pulang');
    final dest = find('Masjid Raya Sumbar', 'K1', 'pergi');

    final plan = TripPlanner.plan(
      ds,
      origin.pos,
      dest.pos,
      destinationLabel: dest.nama,
      originName: origin.nama,
      destinationName: dest.nama,
    );

    final top = plan.options.first;
    expect(top.transferCount, 0, reason: 'harus rute langsung, bukan transit');
    expect(top.legs.first.corridor, 'K3');
    expect(top.legs.first.board.nama, 'TK Aisyiah/Lolongkaran');
    expect(top.legs.last.alight.nama, 'Masjid Raya Sumbar');
    expect(top.walkMinutes, 0);

    // Karena ada rute langsung, transit yang tidak lebih cepat tak ditawarkan.
    expect(plan.options.any((o) => o.corridorChain == 'K3 → K1'), isFalse);
    for (final o in plan.options.where((o) => o.transferCount > 0)) {
      expect(o.totalMinutes, lessThan(top.totalMinutes));
    }

    // Tidak ada opsi yang memerlukan jalan kaki melebihi batas wajar.
    for (final o in plan.options) {
      expect(o.totalWalkKm, lessThanOrEqualTo(AppConfig.maxWalkKm));
    }
  });

  test('dapat menyarankan transit pindah dengan jalan kaki singkat antar dua '
      'halte berbeda nama', () async {
    final ds = await loadHalteDataset();

    // Dekat Simpang Pilakut (K4) → Politeknik Padang (K6). Perlu pindah dari
    // K4 Simpang Ketaping, jalan ±0,2 km ke K6 SMP Muhammadiyah 7.
    final plan = TripPlanner.plan(
      ds,
      const LatLng(-0.9006, 100.3945),
      const LatLng(-0.9175, 100.455394),
      destinationLabel: 'Politeknik Padang',
      destinationName: 'Politeknik Padang',
    );

    final walkTransfer = plan.options.firstWhere(
      (o) =>
          o.transferCount == 1 &&
          o.corridorChain == 'K4 → K6' &&
          o.legs.first.alight.nama == 'Simpang Ketaping' &&
          o.legs.last.board.nama == 'SMP Muhammadiyah 7' &&
          o.legs.last.alight.nama == 'Politeknik Padang',
    );
    expect(walkTransfer.transferWalkKm, greaterThan(0.1));
    expect(walkTransfer.transferWalkKm,
        lessThanOrEqualTo(AppConfig.transferWalkKm));

    for (final o in plan.options) {
      expect(o.totalWalkKm, lessThanOrEqualTo(AppConfig.maxWalkKm));
    }
  });

  test('setiap pasangan halte searah (sampling) menghasilkan opsi langsung '
      'dengan halte naik/turun yang benar', () async {
    final ds = await loadHalteDataset();

    var sampled = 0;
    var index = 0;
    final failures = <String>[];

    for (final c in ds.corridors.values) {
      for (final dir in c.arah.values) {
        final hs = dir.halte;
        for (var i = 0; i < hs.length; i++) {
          for (var j = i + 1; j < hs.length; j++) {
            index++;
            // Sampling deterministik agar test tetap cepat.
            if (index % 22 != 0) continue;

            final o = hs[i].nama;
            final d = hs[j].nama;

            var expectDirect = false;
            for (final cc in ds.corridors.values) {
              for (final dd in cc.arah.values) {
                final oi = _firstIndex(dd.halte, o);
                final di = _firstIndex(dd.halte, d);
                if (oi != null && di != null && oi < di) expectDirect = true;
              }
            }
            if (!expectDirect) continue;
            sampled++;

            final plan = TripPlanner.plan(
              ds,
              hs[i].pos,
              hs[j].pos,
              destinationLabel: d,
              originName: o,
              destinationName: d,
              maxOptions: 100000,
            );
            final ok = plan.options.any((op) =>
                op.transferCount == 0 &&
                op.legs.first.board.nama.toLowerCase() == o.toLowerCase() &&
                op.legs.last.alight.nama.toLowerCase() == d.toLowerCase());
            if (!ok) failures.add('$o -> $d');
          }
        }
      }
    }

    expect(sampled, greaterThan(200));
    expect(failures, isEmpty);
  });
}
