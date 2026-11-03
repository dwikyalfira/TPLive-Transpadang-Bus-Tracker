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
}
