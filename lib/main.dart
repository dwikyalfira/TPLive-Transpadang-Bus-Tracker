import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_navigator.dart';
import 'core/settings.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/tracking/presentation/providers.dart';
import 'features/tracking/presentation/widgets/pinned_bus_overlay.dart';
import 'l10n/app_localizations.dart';

/// Wadah provider root; dipakai bersama observer navigator supaya kartu
/// melayang dapat diubah tanpa BuildContext.
late final ProviderContainer appProviderContainer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preferensi dimuat sebelum UI dibangun agar tema & bahasa tidak "berkedip"
  // saat aplikasi dibuka.
  final prefs = await SharedPreferences.getInstance();
  appProviderContainer = ProviderContainer(
    overrides: [settingsStoreProvider.overrideWithValue(SettingsStore(prefs))],
  );

  // Setiap kali rute berpindah (push/pop), kembalikan kartu bus di-pin ke
  // ukuran mini.
  AppNavigatorObserver.onRouteChanged = () {
    appProviderContainer
        .read(pinnedCardCollapsedProvider.notifier)
        .state = true;
  };
  runApp(UncontrolledProviderScope(
    container: appProviderContainer,
    child: const TransPadangApp(),
  ));
}

/// Warna benih tema aplikasi.
const Color _seedColor = Color(0xFF0B6E4F);

/// Membangun tema Material 3 lengkap (terang/gelap) beserta sub-tema komponen
/// agar gaya seragam tanpa di-hardcode di tiap widget.
///
/// Bila [dynamic] diberikan (dari paket `dynamic_color`, mengikuti warna
/// wallpaper perangkat di Android 12+), dipakai sebagai skema warna; bila
/// null, dijatuhkan ke [ColorScheme.fromSeed].
ThemeData _buildTheme(Brightness brightness, [ColorScheme? dynamic]) {
  final scheme = dynamic ??
      ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: brightness,
      );
  final radius = BorderRadius.circular(14);

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: scheme.surfaceTint,
      elevation: 0,
      scrolledUnderElevation: 3,
    ),
    cardTheme: CardTheme(
      color: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceVariant.withOpacity(0.4),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder:
          OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
  );
}

class TransPadangApp extends ConsumerWidget {
  const TransPadangApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    // Material You: ikuti warna wallpaper perangkat (Android 12+) bila diaktifkan
    // pengguna. Bila tidak, pakai warna benih hijau sebagai gantinya.
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final light = settings.useDynamicColor ? lightDynamic : null;
        final dark = settings.useDynamicColor ? darkDynamic : null;
        return MaterialApp(
          title: 'TPLive',
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          navigatorObservers: [appNavigatorObserver],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: settings.locale,
          theme: _buildTheme(Brightness.light, light),
          darkTheme: _buildTheme(Brightness.dark, dark),
          themeMode: settings.themeMode,
          // Overlay global di atas Navigator: kartu bus di-pin tetap terlihat
          // di semua halaman; guliran layar atau berpindah halaman mengembalikan
          // kartu ke mini.
          builder: (context, child) =>
              RootOverlay(child: child ?? const SizedBox()),
          home: const SplashScreen(),
        );
      },
    );
  }
}