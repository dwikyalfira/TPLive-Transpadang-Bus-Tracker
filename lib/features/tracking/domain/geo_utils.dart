import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../../core/config.dart';

const _distance = Distance();

/// Arah kompas (derajat, 0 = utara) dari [from] ke [to].
double bearingDegrees(LatLng from, LatLng to) {
  final lat1 = from.latitude * math.pi / 180;
  final lat2 = to.latitude * math.pi / 180;
  final dLng = (to.longitude - from.longitude) * math.pi / 180;
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  final deg = math.atan2(y, x) * 180 / math.pi;
  return (deg + 360) % 360;
}

/// Selisih sudut terkecil antara dua arah (0..180).
double angularDifference(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

/// Proyeksi titik [p] ke segmen [a]-[b] (aproksimasi equirectangular).
///
/// Mengembalikan (jarak_km, t) dengan t ∈ [0, 1] posisi relatif pada segmen.
(double, double) projectOnSegment(LatLng p, LatLng a, LatLng b) {
  final latRad = a.latitude * math.pi / 180;
  final kx = math.cos(latRad) * 111.32;
  const ky = 111.32;
  double x(LatLng q) => (q.longitude - a.longitude) * kx;
  double y(LatLng q) => (q.latitude - a.latitude) * ky;
  final bx = x(b), by = y(b);
  final px = x(p), py = y(p);
  final seg2 = bx * bx + by * by;
  var t = seg2 > 0 ? (px * bx + py * by) / seg2 : 0.0;
  t = t.clamp(0.0, 1.0);
  final dx = px - t * bx, dy = py - t * by;
  return (math.sqrt(dx * dx + dy * dy), t);
}

/// Jarak garis lurus antara dua titik, dalam kilometer (Haversine).
///
/// Catatan: `Distance.as(LengthUnit.Kilometer, …)` pada latlong2 0.9.1
/// memotong nilai menjadi bilangan bulat (0 untuk jarak < 1 km), sehingga
/// kita hitung dalam meter lalu bagi 1000.
double distanceKm(LatLng from, LatLng to) =>
    _distance.as(LengthUnit.Meter, from, to) / 1000.0;

/// Estimasi waktu tempuh (menit) berdasarkan jarak dan kecepatan bus.
///
/// Bila kecepatan tidak diketahui atau bus berhenti (< [AppConfig.minMovingSpeedKmh]),
/// dipakai [AppConfig.defaultSpeedKmh]. Mengembalikan `null` bila tidak bisa dihitung.
int? estimateEtaMinutes(double distanceKm, double? speedKmh) {
  final speed = (speedKmh == null || speedKmh < AppConfig.minMovingSpeedKmh)
      ? AppConfig.defaultSpeedKmh
      : speedKmh;
  if (speed <= 0 || distanceKm <= 0) return null;
  final minutes = (distanceKm / speed) * 60;
  if (!minutes.isFinite) return null;
  return minutes.round();
}
