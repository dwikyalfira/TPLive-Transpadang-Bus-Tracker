import 'package:flutter/material.dart';

/// Kunci navigator root.
///
/// Dipakai oleh overlay global (mis. kartu bus yang di-pin) untuk membuka
/// halaman atau bottom sheet dari luar pohon Navigator.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Observer yang memberi tahu bahwa rute telah berpindah (push/pop selesai).
///
/// Tujuan utamanya: mengembalikan kartu bus melayang ke ukuran mini setiap
/// kali pengguna berpindah halaman. [onRouteChanged] diisi dari sisi aplikasi
/// (main.dart) supaya lapisan ini tidak bergantung pada fitur tertentu; dipakai
/// pula di test.
class AppNavigatorObserver extends NavigatorObserver {
  /// Dipanggil (ditunda ke microtask berikutnya) setelah rute berpindah.
  static void Function()? onRouteChanged;

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) =>
      _notify();

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) =>
      _notify();

  /// Ditunda karena perubahan rute terjadi di tengah siklus frame; memperbarui
  /// provider di situ bisa memicu error "modified provider while building".
  void _notify() {
    Future<void>(() => onRouteChanged?.call());
  }
}

/// Instance observer global yang didaftarkan ke [MaterialApp.navigatorObservers].
final AppNavigatorObserver appNavigatorObserver = AppNavigatorObserver();