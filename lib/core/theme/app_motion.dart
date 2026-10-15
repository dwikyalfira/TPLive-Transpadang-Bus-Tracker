import 'package:flutter/animation.dart';

/// Token gerak (motion) Material 3 yang dipakai bersama seluruh aplikasi
/// supaya durasi & kurva transisi konsisten dan tidak di-hardcode di tiap
/// layar.
///
/// Nilai mengikuti skala durasi MD3: short1–short4, medium1–medium4, long1+.
/// Easing "emphasized" MD3 adalah kurva dua segmen; di sini didekati dengan
/// [Cubic] satu segmen yang sangat mendekati (decelerate saat masuk,
/// accelerate saat keluar) karena Flutter SDK tidak menyediakannya bawaan.
abstract final class AppMotion {
  const AppMotion._();

  // --- Durasi (milidetik) ---
  static const Duration short2 = Duration(milliseconds: 100);
  static const Duration short3 = Duration(milliseconds: 150);
  static const Duration short4 = Duration(milliseconds: 200);
  static const Duration medium1 = Duration(milliseconds: 250);
  static const Duration medium2 = Duration(milliseconds: 300);
  static const Duration medium4 = Duration(milliseconds: 400);
  static const Duration long2 = Duration(milliseconds: 500);

  // --- Kurva ---
  /// Standar MD3 untuk transisi antar elemen di dalam layar.
  static const Curve standard = Curves.easeInOutCubic;

  /// Emphasized decelerate: dipakai saat elemen MASUK layar (mulai cepat,
  /// melambat di akhir).
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.70, 0.10, 1.00);

  /// Emphasized accelerate: dipakai saat elemen KELUAR layar.
  static const Curve emphasizedAccelerate = Cubic(0.30, 0.00, 0.80, 0.15);

  /// Fade-through memakai decelerate saat masuk dan accelerate saat keluar.
  static const Curve fadeThroughIn = emphasizedDecelerate;
  static const Curve fadeThroughOut = emphasizedAccelerate;
}
