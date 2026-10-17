import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Format jarak: < 1 km ditampilkan dalam meter. Satuan "m"/"km" netral bahasa.
String formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1)} km';
}

/// Format umur data dari [then] (UTC) relatif ke sekarang.
String formatAge(Duration? age, AppLocalizations l10n) {
  if (age == null) return '-';
  final seconds = age.inSeconds;
  if (seconds < 60) return l10n.ageSeconds(seconds);
  final minutes = age.inMinutes;
  if (minutes < 60) return l10n.ageMinutes(minutes);
  return l10n.ageHours(age.inHours);
}

/// Warna badge per koridor.
Color corridorColor(String corridor) {
  switch (corridor.toUpperCase()) {
    case 'K1':
      return const Color(0xFFC8163F);
    case 'K2':
      return const Color(0xFFEAA221);
    case 'K3':
      return const Color(0xFF5CC49A);
    case 'K4':
      return const Color(0xFF5F9A4F);
    case 'K5':
      return const Color(0xFF1F2A6B);
    case 'K6':
      return const Color(0xFF1E9BDB);
    default:
      return const Color(0xFF546E7A);
  }
}

/// Warna teks/ikon yang kontras di atas [corridorColor] (mis. di badge koridor).
/// Warna terang (K2/K3) memakai teks gelap, warna gelap memakai teks putih.
Color onCorridorColor(String corridor) {
  final color = corridorColor(corridor);
  return onColor(color);
}

/// Warna teks/ikon yang kontras di atas [color].
Color onColor(Color color) =>
    color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

/// Rasio kontras WCAG antara dua warna (1.0 = identik, 21.0 = hitam vs putih).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Menyesuaikan [color] agar rasio kontrasnya terhadap [background] mencapai
/// minimal [minRatio] (default 4.5:1 sesuai WCAG AA untuk teks normal).
/// Arah penyesuaian mengikuti kecerahan [background]: latar gelap dicerahkan,
/// latar terang digelapkan. Warna dikembalikan apa adanya bila sudah cukup.
Color ensureContrast(Color color, Color background, {double minRatio = 4.5}) {
  if (contrastRatio(color, background) >= minRatio) return color;
  final target = background.computeLuminance() < 0.5 ? Colors.white : Colors.black;
  var result = color;
  for (var i = 0; i < 25; i++) {
    result = Color.lerp(result, target, 0.08)!;
    if (contrastRatio(result, background) >= minRatio) break;
  }
  return result;
}

/// Warna koridor untuk dipakai sebagai warna teks/ikon DI ATAS [background]
/// (mis. chip koridor yang tidak terpilih, atau ikon di atas tint lembut).
/// Identitas warna koridor dipertahankan; hanya kecerahannya disesuaikan
/// seperlunya saat [background] terlalu dekat dengan warna koridor — kondisi
/// yang paling sering terjadi di mode gelap untuk K1 (merah) dan K5 (biru tua).
Color corridorOnBackground(String corridor, Color background) =>
    ensureContrast(corridorColor(corridor), background);

/// Warna aksen koridor yang menyesuaikan tema. Di mode gelap, warna digeser
/// ke tone yang lebih terang (prinsip Material 3) agar aksen tetap terlihat
/// dan terbaca di atas permukaan gelap — khususnya warna gelap seperti K1
/// (merah) dan K5 (biru tua) yang nyaris menyatu dengan latar gelap. Di mode
/// terang, warna asli dipertahankan. Dipakai untuk badge, chip, ikon, rel,
/// dan garis aksen.
Color corridorAccent(String corridor, ThemeData theme) {
  final base = corridorColor(corridor);
  if (theme.brightness != Brightness.dark) return base;
  return ensureContrast(base, theme.colorScheme.surface, minRatio: 3.0);
}

/// Intensitas tint latar kartu koridor ringkas (info koridor & daftar bus).
/// Nilainya sama agar warna kartu bus menyatu dengan kartu "Info Koridor".
const double kCorridorCardTintOpacity = 0.06;

/// Tint latar kartu bus yang di-pin; lebih tegas agar kartu melayang menonjol.
const double kCorridorPinnedTintOpacity = 0.14;

/// Latar kartu bernuansa koridor: warna aksen koridor di atas [base], dengan
/// kepekatan [opacity] (default [kCorridorCardTintOpacity]).
Color corridorSurfaceTint(
  String corridor,
  ThemeData theme, {
  required Color base,
  double opacity = kCorridorCardTintOpacity,
}) =>
    Color.alphaBlend(
      corridorAccent(corridor, theme).withOpacity(opacity),
      base,
    );
