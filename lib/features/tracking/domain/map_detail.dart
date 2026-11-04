import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Tingkat detail gambar peta menurut zoom.
///
/// Peta digeser/di-zoom puluhan kali per detik, dan tiap frame jalur koridor
/// diproyeksikan ulang titik demi titik. Saat peta jauh, selisih beberapa meter
/// pada garis lebih kecil dari satu piksel, jadi titik-titiknya bisa dikurangi
/// tanpa terlihat. Level hanya berganti di ambang zoom tertentu, sehingga
/// pembangunan ulang tidak terjadi di tiap frame.

/// Level detail jalur (0 = paling kasar, 3 = data asli) untuk [zoom].
int routeDetailLevel(double zoom) {
  if (zoom < 13.5) return 0;
  if (zoom < 15.5) return 1;
  if (zoom < 17) return 2;
  return 3;
}

/// Toleransi penyederhanaan (meter) untuk [level]; 0 berarti jangan sederhanakan.
double routeSimplifyToleranceMeters(int level) {
  switch (level) {
    case 0:
      return 15;
    case 1:
      return 5;
    case 2:
      return 1.5;
    default:
      return 0;
  }
}

/// Level zoom penanda halte (0..3): ambang 14,5 / 15,5 / 17.
///
/// - 0: titik kecil (hanya terlihat bila satu koridor dipilih)
/// - 1: titik sedang (hanya terlihat bila satu koridor dipilih)
/// - 2: titik sedang, terlihat juga di tab "Semua"
/// - 3: titik besar + label nama
int stopZoomLevel(double zoom) {
  if (zoom < 14.5) return 0;
  if (zoom < 15.5) return 1;
  if (zoom < 17) return 2;
  return 3;
}

/// Menyederhanakan [points] dengan algoritma Douglas–Peucker: titik yang
/// menyimpang kurang dari [toleranceMeters] dari garis lurus antar titik yang
/// dipertahankan dibuang. Titik awal & akhir selalu dipertahankan, urutan tetap.
List<LatLng> simplifyPolyline(List<LatLng> points, double toleranceMeters) {
  final n = points.length;
  if (n <= 2 || toleranceMeters <= 0) return points;

  // Proyeksi lokal (meter) di sekitar lintang rata-rata; cukup akurat untuk
  // jalur sepanjang kota.
  var meanLat = 0.0;
  for (final p in points) {
    meanLat += p.latitude;
  }
  meanLat /= n;
  final kx = 111320.0 * math.cos(meanLat * math.pi / 180);
  const ky = 110574.0;
  final xs = List<double>.generate(n, (i) => points[i].longitude * kx);
  final ys = List<double>.generate(n, (i) => points[i].latitude * ky);

  final keep = List<bool>.filled(n, false)
    ..[0] = true
    ..[n - 1] = true;
  final tolSq = toleranceMeters * toleranceMeters;

  final stack = <int>[0, n - 1];
  while (stack.isNotEmpty) {
    final end = stack.removeLast();
    final start = stack.removeLast();
    if (end <= start + 1) continue;

    final ax = xs[start], ay = ys[start];
    final dx = xs[end] - ax, dy = ys[end] - ay;
    final lenSq = dx * dx + dy * dy;

    var maxSq = -1.0;
    var index = -1;
    for (var i = start + 1; i < end; i++) {
      final px = xs[i] - ax, py = ys[i] - ay;
      double distSq;
      if (lenSq == 0) {
        distSq = px * px + py * py;
      } else {
        final t = ((px * dx + py * dy) / lenSq).clamp(0.0, 1.0);
        final cx = t * dx - px, cy = t * dy - py;
        distSq = cx * cx + cy * cy;
      }
      if (distSq > maxSq) {
        maxSq = distSq;
        index = i;
      }
    }
    if (maxSq > tolSq) {
      keep[index] = true;
      stack
        ..add(start)
        ..add(index)
        ..add(index)
        ..add(end);
    }
  }

  return [
    for (var i = 0; i < n; i++)
      if (keep[i]) points[i],
  ];
}
