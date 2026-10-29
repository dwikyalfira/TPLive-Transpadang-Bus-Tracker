import 'package:latlong2/latlong.dart';

import 'geo_utils.dart' as geo;

/// Perkiraan kedatangan bus ke lokasi pengguna.
///
/// Perhitungannya sengaja sederhana dan **jujur**: jarak garis lurus bus →
/// pengguna dibagi kecepatan bus saat ini ([geo.estimateEtaMinutes]), bukan ETA
/// jaringan jalan. Angka ini berguna sebagai "kira-kira bus ini masih N menit
/// lagi ke sini", dengan pendekatan yang sama seperti estimasi jarak ke halte
/// berikutnya pada kartu bus.
///
/// Estimasi **tidak pernah disembunyikan** karena arah gerak: dulu ada
/// penyaring "bus menjauh", tetapi arah bus dari server dan akurasi GPS yang
/// berbeda antar layar membuat estimasi hilang-muncul sendiri. Jarak
/// ([distanceKm]) ikut ditampilkan supaya pembaca bisa menilai sendiri bila
/// angkanya membesar (bus menjauh).
class UserArrival {
  /// Jarak garis lurus bus → pengguna, dalam kilometer.
  final double distanceKm;

  /// Perkiraan waktu tempuh ke pengguna (menit); `null` hanya bila angkanya
  /// tidak bisa dihitung (mis. jarak tidak valid).
  final int? etaMinutes;

  const UserArrival({required this.distanceKm, required this.etaMinutes});

  /// Ambang "bus sudah di sekitar pengguna" (50 m).
  static const double hereKm = 0.05;

  /// Benar bila bus praktis sudah berada di titik pengguna.
  bool get isHere => distanceKm <= hereKm;

  /// Apakah ada estimasi menit yang layak ditampilkan.
  bool get hasEta => etaMinutes != null;

  /// Menghitung perkiraan kedatangan [busPosition] ke [user].
  static UserArrival? estimate({
    required LatLng busPosition,
    required LatLng user,
    double? speedKmh,
  }) {
    final km = geo.distanceKm(busPosition, user);
    if (!km.isFinite) return null;

    if (km <= hereKm) {
      return UserArrival(distanceKm: km, etaMinutes: 0);
    }

    return UserArrival(
      distanceKm: km,
      etaMinutes: geo.estimateEtaMinutes(km, speedKmh),
    );
  }
}
