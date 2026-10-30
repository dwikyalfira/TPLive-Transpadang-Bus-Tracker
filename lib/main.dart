import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_navigator.dart';
import 'core/settings.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/app_theme.dart';
import 'features/tracking/presentation/home_screen.dart';
import 'features/tracking/presentation/providers.dart';
import 'features/tracking/presentation/widgets/pinned_bus_overlay.dart';
import 'features/trip/data/saved_places_store.dart';
import 'features/trip/presentation/trip_providers.dart';
import 'l10n/app_localizations.dart';

/// Wadah provider root; dipakai bersama observer navigator supaya kartu
/// melayang dapat diubah tanpa BuildContext.
late final ProviderContainer appProviderContainer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tampilan tepi-ke-tepi (edge-to-edge) sesuai Material 3: konten aplikasi
  // digambar di belakang system bar, sementara ikon system bar menyesuaikan
  // tema (diatur per-frame lewat AnnotatedRegion di TransPadangApp).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Preferensi dimuat sebelum UI dibangun agar tema & bahasa tidak "berkedip"
  // saat aplikasi dibuka.
  final prefs = await SharedPreferences.getInstance();
  appProviderContainer = ProviderContainer(
    overrides: [
      settingsStoreProvider.overrideWithValue(SettingsStore(prefs)),
      savedPlacesStoreProvider.overrideWithValue(SavedPlacesStore(prefs)),
    ],
  );

  // Setiap kali rute berpindah (push/pop), kembalikan kartu bus di-pin ke
  // ukuran mini.
  AppNavigatorObserver.onRouteChanged = () {
    appProviderContainer.read(pinnedCardCollapsedProvider.notifier).state =
        true;
  };

  // Pantau status aplikasi (depan/belakang) supaya koneksi live bisa ditutup
  // saat aplikasi tidak terlihat — lihat [liveUpdatesAllowedProvider].
  WidgetsBinding.instance
      .addObserver(_AppLifecycleObserver(appProviderContainer));

  runApp(UncontrolledProviderScope(
    container: appProviderContainer,
    child: const TransPadangApp(),
  ));
}

/// Meneruskan perubahan siklus hidup aplikasi ke [appPausedProvider].
///
/// Hanya satu observer dipasang di akar aplikasi (bukan di tiap layar) agar
/// status tidak saling menimpa saat beberapa layar hidup bersamaan.
class _AppLifecycleObserver with WidgetsBindingObserver {
  _AppLifecycleObserver(this._container);

  final ProviderContainer _container;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final paused = switch (state) {
      AppLifecycleState.paused ||
      AppLifecycleState.hidden ||
      AppLifecycleState.detached =>
        true,
      AppLifecycleState.resumed || AppLifecycleState.inactive => false,
    };
    final notifier = _container.read(appPausedProvider.notifier);
    if (notifier.state != paused) notifier.state = paused;
  }
}

class TransPadangApp extends ConsumerWidget {
  const TransPadangApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    // Material You: ikuti warna wallpaper perangkat (Android 12+) bila diaktifkan
    // pengguna. Bila tidak, pakai warna benih oranye logo sebagai gantinya.
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final light = settings.useDynamicColor ? lightDynamic : null;
        final dark = settings.useDynamicColor ? darkDynamic : null;
        final lightTheme = buildAppTheme(Brightness.light, light);
        final darkTheme = buildAppTheme(Brightness.dark, dark);
        return MaterialApp(
          title: 'TPLive',
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          navigatorObservers: [appNavigatorObserver],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: settings.locale,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: settings.themeMode,
          // Interpolasi tema (Terang/Gelap/Dynamic Color) dipersingkat: setiap
          // frame meng-interpolasi seluruh `ThemeData` dan me-rebuild subtree,
          // jadi 400 ms terasa berat di perangkat kelas menengah.
          themeAnimationDuration: AppMotion.medium1,
          themeAnimationCurve: AppMotion.standard,
          // Overlay global di atas Navigator: kartu bus di-pin tetap terlihat
          // di semua halaman; guliran layar atau berpindah halaman mengembalikan
          // kartu ke mini. System bar diwarnai transparan agar menyatu dengan
          // latar tema (edge-to-edge Material 3).
          builder: (context, child) {
            final brightness = Theme.of(context).brightness;
            final overlay = SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: brightness == Brightness.dark
                  ? Brightness.dark
                  : Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarContrastEnforced: false,
            );
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlay,
              child: RootOverlay(child: child ?? const SizedBox()),
            );
          },
          // Langsung ke beranda: tidak ada splash buatan Flutter. Splash native
          // Android (`LaunchTheme`) sudah menutupi jeda engine sampai frame
          // pertama, dan semua yang dibutuhkan sebelum UI tampil (preferensi,
          // tema, bahasa) sudah dimuat di [main] — jadi layar pembuka tambahan
          // hanya menambah ~1,8 detik logo yang tampil dua kali. Status "belum
          // siap" (GPS/koneksi) ditampilkan di beranda lewat `LoadingStateView`.
          home: const HomeScreen(),
        );
      },
    );
  }
}
