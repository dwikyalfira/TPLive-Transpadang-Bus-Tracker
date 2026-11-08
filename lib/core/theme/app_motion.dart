import 'package:flutter/widgets.dart';

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
  static const Duration short1 = Duration(milliseconds: 50);
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

  /// Linear: hanya untuk indikator progres (tidak boleh melambat di akhir).
  static const Curve linear = Curves.linear;

  // --- Gestur tarik (drag) ---
  /// Pegas saat sheet kembali ke posisi setelah dilepas: cepat, dengan sedikit
  /// pantulan karena jari baru saja memberi "gaya". Khusus akhir gestur;
  /// jangan dipakai untuk aksi tombol.
  static final SpringDescription sheetSettleSpring =
      SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 0.75,
  );

  /// Pegas saat sheet ditutup: teredam kritis, sehingga keluar layar tanpa
  /// pantulan namun tetap meneruskan kecepatan jari.
  static final SpringDescription sheetDismissSpring =
      SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 1,
  );

  /// Toleransi simulasi gestur yang satuannya piksel (bawaan Flutter 0,001
  /// terlalu halus dan memperpanjang ekor animasi tanpa terlihat).
  static const Tolerance gestureTolerance =
      Tolerance(distance: 0.5, velocity: 5);

  /// Kecepatan turun (px/detik) yang menutup sheet walau jaraknya pendek.
  static const double sheetFlingVelocity = 280;

  /// Fraksi jarak tempuh sheet yang harus dilewati untuk menutup tanpa fling.
  static const double sheetDismissDistanceRatio = 0.5;

  /// Perbandingan gerak elemen terhadap jari saat ditarik melewati batas.
  static const double rubberBandFactor = 0.2;

  /// Jarak maksimum (piksel) elemen dapat ditarik melewati batas.
  static const double rubberBandLimit = 16;

  /// Mengubah jarak tarik jari [distance] (>= 0) melewati batas menjadi jarak
  /// gerak elemen: awalnya [rubberBandFactor] dari jari, lalu makin berat dan
  /// mendekati [rubberBandLimit] tanpa pernah berhenti mendadak.
  static double rubberBand(double distance) {
    final scaled = distance * rubberBandFactor;
    return scaled * rubberBandLimit / (scaled + rubberBandLimit);
  }

  /// Kebalikan [rubberBand]: jarak jari yang menghasilkan jarak elemen
  /// [offset], dipakai saat elemen ditangkap lagi di tengah animasi.
  static double rubberBandInverse(double offset) {
    final bounded = offset.clamp(0.0, rubberBandLimit * 0.99);
    return bounded *
        rubberBandLimit /
        (rubberBandFactor * (rubberBandLimit - bounded));
  }

  /// Durasi yang menghormati preferensi aksesibilitas "hapus animasi"
  /// ([MediaQueryData.disableAnimations]).
  ///
  /// Animasi gerak (slide/scale/ubah ukuran) dimatikan sepenuhnya; perubahan
  /// tetap terjadi, hanya tanpa pergerakan.
  static Duration resolve(BuildContext context, Duration duration) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return reduceMotion ? Duration.zero : duration;
  }
}
