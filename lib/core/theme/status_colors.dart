import 'package:flutter/material.dart';

/// Warna semantik status layanan. Sengaja bukan bagian dari `ColorScheme`
/// (hijau/kuning/ungu tidak ada di skema dinamis), tetapi dipusatkan di sini
/// supaya satu sumber dan punya varian untuk tema gelap.
abstract final class StatusColors {
  const StatusColors._();

  /// Ungu "di luar jam operasional" — pekat, untuk tema terang.
  static const Color night = Color(0xFF7B1FA2);

  /// Varian cerah agar kontras terhadap `surface` gelap tetap cukup.
  static const Color nightOnDark = Color(0xFFCE93D8);

  static Color nightFor(Brightness brightness) =>
      brightness == Brightness.dark ? nightOnDark : night;

  /// Hijau "berhasil" untuk tema terang (kontras ≥ 4,5:1 di atas putih).
  static const Color success = Color(0xFF2E7D32);

  /// Varian cerah agar tetap terbaca di atas `surface` gelap.
  static const Color successOnDark = Color(0xFF81C784);

  static Color successFor(Brightness brightness) =>
      brightness == Brightness.dark ? successOnDark : success;
}
