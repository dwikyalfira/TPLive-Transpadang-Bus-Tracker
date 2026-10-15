import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_navigator.dart';
import 'core/settings.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/tracking/presentation/providers.dart';
import 'features/tracking/presentation/widgets/pinned_bus_overlay.dart';
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
              statusBarBrightness:
                  brightness == Brightness.dark ? Brightness.dark : Brightness.light,
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
          home: const SplashScreen(),
        );
      },
    );
  }
}