import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/domain/halte_tracker.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';
import 'package:transpadang_live/features/trip/domain/trip_endpoint.dart';
import 'package:transpadang_live/features/trip/domain/trip_planner.dart';
import 'package:transpadang_live/features/trip/presentation/trip_providers.dart';

Halte _h(double lat, double lng, String nama) =>
    Halte(nama: nama, pos: LatLng(lat, lng));

CorridorDirection _dir(String label, List<Halte> halte) =>
    CorridorDirection(label: label, halte: halte);

HalteDataset _dataset(Map<String, CorridorDirection> perCorridor) {
  final corridors = <String, CorridorStops>{};
  perCorridor.forEach((kode, dir) {
    corridors[kode] = CorridorStops(kode: kode, arah: {'pergi': dir});
  });
  return HalteDataset(corridors);
}

List<HalteEntry> _entries(HalteDataset dataset) {
  final container = ProviderContainer(
    overrides: [halteDatasetProvider.overrideWith((ref) => dataset)],
  );
  addTearDown(container.dispose);
  return container.read(halteEntriesProvider);
}

void main() {
  group('entri halte: gabung per nama + sel ~50 m', () {
    test('nama sama di lokasi hampir sama digabung jadi satu entri', () {
      final dataset = _dataset({
        'K1': _dir('A - B', [_h(-0.9000, 100.3000, 'Pasar Teluk Kabung')]),
        'K3': _dir('C - D', [_h(-0.9002, 100.3001, 'Pasar Teluk Kabung')]),
      });

      final entries = _entries(dataset);
      expect(entries, hasLength(1));
      // Koridor kedua ikut menempel pada entri yang sama.
      expect(entries.single.corridors, {'K1', 'K3'});
    });

    test('nama sama tetapi terpisah ~350 m tetap dua entri', () {
      final dataset = _dataset({
        'K1': _dir('A - B', [_h(-0.9000, 100.3000, 'Pasar Teluk Kabung')]),
        'K3': _dir('C - D', [_h(-0.9031, 100.3000, 'Pasar Teluk Kabung')]),
      });

      final entries = _entries(dataset);
      expect(entries, hasLength(2));
      for (final entry in entries) {
        expect(entry.corridors, hasLength(1));
      }
      final lats = entries.map((e) => e.halte.pos.latitude).toList()..sort();
      expect(lats.first, lessThan(lats.last));
    });

    test('nama berbeda di lokasi sama tetap entri terpisah', () {
      final dataset = _dataset({
        'K1': _dir('A - B', [_h(-0.9000, 100.3000, 'Halte Satu')]),
        'K3': _dir('C - D', [_h(-0.9000, 100.3000, 'Halte Dua')]),
      });
      expect(_entries(dataset), hasLength(2));
    });
  });

  group('perencana: koordinat lebih dulu, nama sebagai penentu', () {
    /// Dua halte senama, salah satunya dekat dengan titik asal; halte lain
    /// ("Halte Dekat") persis di titik asal.
    HalteDataset twoPasars() => _dataset({
          'K3': _dir('D - A', [
            _h(-0.900, 100.3000, 'Pasar'),
            _h(-0.900, 100.3010, 'Halte Dekat'),
            _h(-0.900, 100.3035, 'Pasar'),
            _h(-0.900, 100.3100, 'Ujung'),
          ]),
        });

    /// Hanya satu "Pasar", dan letaknya ~500 m dari titik asal.
    HalteDataset farPasar() => _dataset({
          'K3': _dir('D - A', [
            _h(-0.900, 100.2965, 'Pasar'),
            _h(-0.900, 100.3010, 'Halte Dekat'),
            _h(-0.900, 100.3100, 'Ujung'),
          ]),
        });

    test('halte senama dalam 150 m menang atas halte terdekat', () {
      final plan = TripPlanner.plan(
        twoPasars(),
        const LatLng(-0.900, 100.301),
        const LatLng(-0.900, 100.310),
        destinationLabel: 'Ujung',
        originName: 'Pasar',
        destinationName: 'Ujung',
      );

      expect(plan.hasOptions, isTrue);
      final option = plan.options.first;
      expect(option.board.nama, 'Pasar');
      // 'Pasar' terdekat ke titik asal (bukan 'Halte Dekat' yang persis di titik).
      expect(option.board.pos.longitude, closeTo(100.300, 1e-9));
      expect(option.alight.nama, 'Ujung');
    });

    test('nama tidak dipakai bila haltenya lebih jauh dari 150 m', () {
      final plan = TripPlanner.plan(
        farPasar(),
        const LatLng(-0.900, 100.301),
        const LatLng(-0.900, 100.310),
        destinationLabel: 'Ujung',
        originName: 'Pasar',
        destinationName: 'Ujung',
      );

      expect(plan.hasOptions, isTrue);
      expect(plan.options.first.board.nama, 'Halte Dekat');
    });
  });

  group('histeresis halte', () {
    test('perpindahan baru diterapkan setelah dua pembacaan berturut', () {
      final hysteresis = HalteHysteresis(requiredHits: 2);

      expect(hysteresis.resolve('K3|11', 5), 5);
      expect(hysteresis.resolve('K3|11', 6), 5, reason: 'baru satu kali');
      expect(hysteresis.resolve('K3|11', 6), 6, reason: 'dua kali berturut');
    });

    test('goyangan sesaat tidak membalik penanda', () {
      final hysteresis = HalteHysteresis(requiredHits: 2);
      hysteresis.resolve('K3|11', 5);
      hysteresis.resolve('K3|11', 5);

      // Satu bacaan melompat lalu kembali: penanda tetap di 5.
      expect(hysteresis.resolve('K3|11', 6), 5);
      expect(hysteresis.resolve('K3|11', 5), 5);
      expect(hysteresis.resolve('K3|11', 5), 5);
    });

    test('forget melupakan riwayat satu bus', () {
      final hysteresis = HalteHysteresis(requiredHits: 2);
      hysteresis.resolve('K3|11', 5);
      hysteresis.resolve('K3|11', 6);

      hysteresis.forget('K3|11');
      expect(hysteresis.resolve('K3|11', 9), 9);
    });

    test('status per bus tidak saling memengaruhi', () {
      final hysteresis = HalteHysteresis(requiredHits: 2);
      hysteresis.resolve('K3|11', 5);
      hysteresis.resolve('K3|12', 2);

      expect(hysteresis.resolve('K3|11', 6), 5);
      expect(hysteresis.resolve('K3|12', 3), 2);
    });
  });
}
