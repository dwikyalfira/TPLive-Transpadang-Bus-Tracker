import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/domain/geo_utils.dart';

void main() {
  group('Bus.fromJson', () {
    test('menormalkan latitude/longitude yang terbalik di server', () {
      final bus = Bus.fromJson({
        'bus': '65',
        'longitude': '-0.899045',
        'latitude': '100.38996444',
        'corridor': 'K3',
        'direct': '100',
        'speed': '28',
        'route': 'RTH Imam Bonjol - Balaikota',
        'last_update': '2026-10-12 12:09:28',
      });

      expect(bus.number, '65');
      expect(
          bus.lat, closeTo(-0.899045, 1e-9)); // berasal dari field 'longitude'
      expect(bus.lng,
          closeTo(100.38996444, 1e-9)); // berasal dari field 'latitude'
      expect(bus.corridor, 'K3');
      expect(bus.speedKmh, 28);
      expect(bus.heading, 100);
      // Waktu WIB (UTC+7) dikonversi ke UTC.
      expect(bus.lastUpdate, DateTime.utc(2026, 10, 12, 5, 9, 28));
    });
  });

  group('estimateEtaMinutes', () {
    test('menghitung ETA normal', () {
      expect(estimateEtaMinutes(10, 30), 20); // 10 km @ 30 km/j = 20 menit
    });

    test('memakai kecepatan default saat bus berhenti', () {
      expect(estimateEtaMinutes(1, 0), 3); // 1 km @ 20 km/j = 3 menit
      expect(estimateEtaMinutes(1, 2), 3);
    });

    test('mengembalikan null bila jarak nol', () {
      expect(estimateEtaMinutes(0, 30), isNull);
    });
  });

  group('distanceKm', () {
    test('jarak nol untuk titik yang sama', () {
      const point = LatLng(-0.9, 100.4);
      expect(distanceKm(point, point), closeTo(0, 1e-9));
    });

    test('jarak wajar antar dua titik di Padang', () {
      const a = LatLng(-0.947, 100.417);
      const b = LatLng(-0.883, 100.352);
      final d = distanceKm(a, b);
      expect(d, greaterThan(5));
      expect(d, lessThan(15));
    });
  });
}
