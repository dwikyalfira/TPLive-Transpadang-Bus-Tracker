import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/domain/geo_utils.dart';
import 'package:transpadang_live/features/tracking/domain/halte_tracker.dart';
import 'package:transpadang_live/features/tracking/domain/heading_tracker.dart';

CorridorStops _sampleCorridor() {
  const pergi = CorridorDirection(
    label: 'Utara \u2192 Selatan',
    halte: [
      Halte(nama: 'A', pos: LatLng(-0.90, 100.40)),
      Halte(nama: 'B', pos: LatLng(-0.91, 100.40)),
      Halte(nama: 'C', pos: LatLng(-0.92, 100.40)),
    ],
  );
  const pulang = CorridorDirection(
    label: 'Selatan \u2192 Utara',
    halte: [
      Halte(nama: 'C', pos: LatLng(-0.92, 100.40)),
      Halte(nama: 'B', pos: LatLng(-0.91, 100.40)),
      Halte(nama: 'A', pos: LatLng(-0.90, 100.40)),
    ],
  );
  return const CorridorStops(
      kode: 'KX', arah: {'pergi': pergi, 'pulang': pulang});
}

Bus _bus({required double lat, required double heading}) => Bus(
      number: '1',
      lat: lat,
      lng: 100.40,
      corridor: 'KX',
      route: '',
      heading: heading,
      speedKmh: 20,
      lastUpdate: null,
    );

void main() {
  final dataset = HalteDataset({'KX': _sampleCorridor()});

  group('bearing & sudut', () {
    test('bearingDegrees ke arah selatan mendekati 180', () {
      final b = bearingDegrees(
          const LatLng(-0.90, 100.40), const LatLng(-0.92, 100.40));
      expect((b - 180).abs(), lessThan(1));
    });

    test('angularDifference memilih sudut terkecil', () {
      expect(angularDifference(350, 10), 20);
      expect(angularDifference(10, 170), 160);
    });
  });

  group('HalteTracker', () {
    test('memilih arah pergi saat bus menuju selatan', () {
      final p = HalteTracker.track(_bus(lat: -0.905, heading: 180), dataset);
      expect(p, isNotNull);
      expect(p!.arahKey, 'pergi');
      expect(p.nextStep!.halte.nama, 'B');
      expect(p.currentStep!.halte.nama, 'A');
    });

    test('memilih arah pulang saat bus menuju utara', () {
      final p = HalteTracker.track(_bus(lat: -0.915, heading: 0), dataset);
      expect(p, isNotNull);
      expect(p!.arahKey, 'pulang');
      expect(p.nextStep!.halte.nama, 'B');
      expect(p.currentStep!.halte.nama, 'C');
    });

    test('menandai halte yang sudah terlewati', () {
      final p = HalteTracker.track(_bus(lat: -0.918, heading: 180), dataset)!;
      final passed = p.steps.where((s) => s.mark == HalteMark.passed).length;
      expect(passed, greaterThanOrEqualTo(1));
      expect(p.nextStep!.halte.nama, 'C');
    });

    test('null untuk koridor tak dikenal', () {
      const bus = Bus(
        number: '1',
        lat: -0.9,
        lng: 100.4,
        corridor: 'ZZ',
        route: 'r',
        lastUpdate: null,
      );
      expect(HalteTracker.track(bus, dataset), isNull);
    });

    test('destinationLabel sesuai arah', () {
      final p = HalteTracker.track(_bus(lat: -0.905, heading: 180), dataset)!;
      expect(p.destinationLabel, 'C');
      final u = HalteTracker.track(_bus(lat: -0.915, heading: 0), dataset)!;
      expect(u.destinationLabel, 'A');
    });

    test('destinationLabel memakai terminus route resmi sesuai arah (K3)', () {
      const k3 = CorridorStops(
        kode: 'K3',
        arah: {
          'pergi': CorridorDirection(label: 'p', halte: [
            Halte(nama: 'Ruas Hasanuddin', pos: LatLng(-0.89, 100.40)),
            Halte(
                nama: 'Taman Digital / Balai Kota', pos: LatLng(-0.94, 100.40)),
          ]),
          'pulang': CorridorDirection(label: 'q', halte: [
            Halte(
                nama: 'Taman Digital / Balai Kota', pos: LatLng(-0.94, 100.40)),
            Halte(nama: 'Ruas Hasanuddin', pos: LatLng(-0.89, 100.40)),
          ]),
        },
      );
      const ds = HalteDataset({'K3': k3});
      const route =
          'RTH Imam Bonjol Ruas Hasanuddin - Pusat Pemerintahan Balai Kota Padang';
      const pergi = Bus(
        number: '1',
        lat: -0.93,
        lng: 100.40,
        corridor: 'K3',
        route: route,
        heading: 180,
        speedKmh: 20,
        lastUpdate: null,
      );
      expect(HalteTracker.track(pergi, ds)!.destinationLabel,
          'Pusat Pemerintahan Balai Kota Padang');

      const pulang = Bus(
        number: '2',
        lat: -0.90,
        lng: 100.40,
        corridor: 'K3',
        route: route,
        heading: 0,
        speedKmh: 20,
        lastUpdate: null,
      );
      expect(HalteTracker.track(pulang, ds)!.destinationLabel,
          'RTH Imam Bonjol Ruas Hasanuddin');
    });

    test('K1 pergi menuju endpoint pertama route', () {
      const k1 = CorridorStops(
        kode: 'K1',
        arah: {
          'pergi': CorridorDirection(label: 'p', halte: [
            Halte(nama: 'Mega Permai', pos: LatLng(-0.85, 100.40)),
            Halte(nama: 'Terminus Utara', pos: LatLng(-0.89, 100.40)),
          ]),
          'pulang': CorridorDirection(label: 'q', halte: [
            Halte(nama: 'Terminus Utara', pos: LatLng(-0.89, 100.40)),
            Halte(nama: 'Mega Permai', pos: LatLng(-0.85, 100.40)),
          ]),
        },
      );
      const ds = HalteDataset({'K1': k1});
      const route = 'RTH Imam Bonjol - Mega Permai Lubuk Buaya';
      const pergi = Bus(
        number: '1',
        lat: -0.88,
        lng: 100.40,
        corridor: 'K1',
        route: route,
        heading: 180,
        speedKmh: 20,
        lastUpdate: null,
      );
      expect(
          HalteTracker.track(pergi, ds)!.destinationLabel, 'RTH Imam Bonjol');
    });

    test('pakai estimatedHeading bila heading server tidak ada', () {
      const bus = Bus(
        number: '1',
        lat: -0.915,
        lng: 100.40,
        corridor: 'KX',
        route: 'r',
        lastUpdate: null,
      );
      final p = HalteTracker.track(bus, dataset, estimatedHeading: 0)!;
      expect(p.arahKey, 'pulang');
      expect(p.resolvedHeading, 0);
    });
  });

  group('HeadingTracker', () {
    test('mendeteksi gerak ke selatan dari riwayat posisi', () {
      final tracker = HeadingTracker();
      final t0 = DateTime.utc(2026, 10, 12, 6, 0, 0);
      for (var i = 0; i < 5; i++) {
        final bus = Bus(
          number: '9',
          lat: -0.90 - i * 0.002,
          lng: 100.40,
          corridor: 'KX',
          route: 'r',
          lastUpdate: null,
        );
        final h = tracker.update(bus, t0.add(Duration(seconds: i * 5)));
        if (i == 4) {
          expect(h, isNotNull);
          expect((h! - 180).abs(), lessThan(2));
        }
      }
    });

    test('null bila bus belum bergerak', () {
      final tracker = HeadingTracker();
      final t0 = DateTime.utc(2026, 10, 12, 6, 0, 0);
      const bus = Bus(
        number: '9',
        lat: -0.90,
        lng: 100.40,
        corridor: 'KX',
        route: 'r',
        lastUpdate: null,
      );
      tracker.update(bus, t0);
      final h = tracker.update(bus, t0.add(const Duration(seconds: 5)));
      expect(h, isNull);
    });
  });
}
