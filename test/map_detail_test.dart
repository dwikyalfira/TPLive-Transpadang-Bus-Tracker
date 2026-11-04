import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/features/tracking/domain/map_detail.dart';

/// Jarak titik ke garis (meter) pada proyeksi lokal — untuk memeriksa bahwa
/// hasil penyederhanaan tidak menyimpang melebihi toleransi.
double _distToSegmentMeters(LatLng p, LatLng a, LatLng b) {
  const ky = 110574.0;
  final kx = 111320.0 * math.cos(a.latitude * math.pi / 180);
  final px = (p.longitude - a.longitude) * kx,
      py = (p.latitude - a.latitude) * ky;
  final dx = (b.longitude - a.longitude) * kx,
      dy = (b.latitude - a.latitude) * ky;
  final len = dx * dx + dy * dy;
  final t = len == 0 ? 0.0 : ((px * dx + py * dy) / len).clamp(0.0, 1.0);
  final cx = t * dx - px, cy = t * dy - py;
  return math.sqrt(cx * cx + cy * cy);
}

void main() {
  group('simplifyPolyline', () {
    test('garis lurus dengan titik tengah dibuang, ujung dipertahankan', () {
      final line = [
        for (var i = 0; i <= 10; i++) LatLng(-0.9, 100.30 + i * 0.001),
      ];
      final out = simplifyPolyline(line, 2);
      expect(out, [line.first, line.last]);
    });

    test('tikungan yang melebihi toleransi dipertahankan', () {
      // Sudut siku ~111 m: jauh di atas toleransi 15 m.
      const corner = LatLng(-0.9, 100.301);
      final path = [
        const LatLng(-0.9, 100.300),
        corner,
        const LatLng(-0.901, 100.301),
      ];
      expect(simplifyPolyline(path, 15), path);
    });

    test('hasil tetap berurutan, berawal/berakhir sama, dan dalam toleransi',
        () {
      // Gelombang halus ~8 m amplitudo, 200 titik.
      final wave = [
        for (var i = 0; i < 200; i++)
          LatLng(-0.9 + 0.00007 * math.sin(i / 8), 100.30 + i * 0.0001),
      ];
      for (final tol in [1.5, 5.0, 15.0]) {
        final out = simplifyPolyline(wave, tol);
        expect(out.first, wave.first);
        expect(out.last, wave.last);
        expect(out.length, lessThanOrEqualTo(wave.length));

        // Setiap titik asli harus ada dalam toleransi dari hasil sederhana.
        for (final p in wave) {
          var best = double.infinity;
          for (var i = 0; i < out.length - 1; i++) {
            best = math.min(best, _distToSegmentMeters(p, out[i], out[i + 1]));
          }
          expect(best, lessThanOrEqualTo(tol + 0.01));
        }
      }
      // Toleransi lebih besar → titik lebih sedikit.
      expect(simplifyPolyline(wave, 15).length,
          lessThan(simplifyPolyline(wave, 1.5).length));
    });

    test('toleransi 0 atau jalur sangat pendek dikembalikan apa adanya', () {
      final two = [const LatLng(-0.9, 100.3), const LatLng(-0.91, 100.31)];
      expect(simplifyPolyline(two, 15), same(two));
      final many = [for (var i = 0; i < 5; i++) LatLng(-0.9, 100.3 + i * 0.01)];
      expect(simplifyPolyline(many, 0), same(many));
    });
  });

  group('level zoom', () {
    test('routeDetailLevel berganti tepat di ambang', () {
      expect(routeDetailLevel(12.5), 0);
      expect(routeDetailLevel(13.49), 0);
      expect(routeDetailLevel(13.5), 1);
      expect(routeDetailLevel(15.49), 1);
      expect(routeDetailLevel(15.5), 2);
      expect(routeDetailLevel(16.99), 2);
      expect(routeDetailLevel(17), 3);
      expect(routeDetailLevel(18), 3);
    });

    test('toleransi: makin dekat makin halus, level 3 = data asli', () {
      expect(routeSimplifyToleranceMeters(0),
          greaterThan(routeSimplifyToleranceMeters(1)));
      expect(routeSimplifyToleranceMeters(1),
          greaterThan(routeSimplifyToleranceMeters(2)));
      expect(routeSimplifyToleranceMeters(3), 0);
    });

    test('stopZoomLevel sama dengan ambang halte sebelumnya (14,5/15,5/17)',
        () {
      expect(stopZoomLevel(14.49), 0);
      expect(stopZoomLevel(14.5), 1);
      expect(stopZoomLevel(15.49), 1);
      expect(stopZoomLevel(15.5), 2);
      expect(stopZoomLevel(16.99), 2);
      expect(stopZoomLevel(17), 3);
    });
  });
}
