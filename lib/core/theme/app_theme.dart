import 'package:flutter/material.dart';

/// Warna benih tema (oranye logo TPLive) yang dipakai saat warna dinamis
/// (Material You) dimatikan atau tidak tersedia.
const Color appSeedColor = Color(0xFFF47F38);

/// Skala bentuk (shape) Material 3 agar radius konsisten di seluruh aplikasi.
abstract final class AppShape {
  const AppShape._();

  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double extraLarge = 28;

  static BorderRadius get extraSmallRadius => BorderRadius.circular(extraSmall);
  static BorderRadius get smallRadius => BorderRadius.circular(small);
  static BorderRadius get mediumRadius => BorderRadius.circular(medium);
  static BorderRadius get largeRadius => BorderRadius.circular(large);
  static BorderRadius get extraLargeRadius => BorderRadius.circular(extraLarge);

  /// Sudut atas penuh (mis. bottom sheet).
  static const BorderRadius topExtraLarge = BorderRadius.vertical(
    top: Radius.circular(extraLarge),
  );
}

/// Membangun [ThemeData] Material 3 lengkap (terang/gelap) beserta sub-tema
/// komponen, agar gaya seragam tanpa di-hardcode di tiap widget.
///
/// Bila [dynamic] diberikan (dari paket `dynamic_color`, mengikuti warna
/// wallpaper perangkat di Android 12+), dipakai sebagai skema warna; bila
/// null, dijatuhkan ke [ColorScheme.fromSeed] dengan [appSeedColor].
ThemeData buildAppTheme(Brightness brightness, [ColorScheme? dynamic]) {
  final scheme = dynamic ??
      ColorScheme.fromSeed(
        seedColor: appSeedColor,
        brightness: brightness,
      );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final textTheme = base.textTheme;

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: scheme.surfaceTint,
      elevation: 0,
      scrolledUnderElevation: 3,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardTheme(
      color: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppShape.mediumRadius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: AppShape.extraLargeRadius,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      // Material 3: snackbar bersudut 4dp.
      shape: RoundedRectangleBorder(
        borderRadius: AppShape.extraSmallRadius,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      shape: const RoundedRectangleBorder(borderRadius: AppShape.topExtraLarge),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceVariant,
      side: BorderSide(color: scheme.outlineVariant),
      shape: const StadiumBorder(),
      labelStyle: textTheme.labelLarge,
      showCheckmark: false,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      shape: RoundedRectangleBorder(borderRadius: AppShape.mediumRadius),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: AppShape.extraSmallRadius,
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceVariant.withOpacity(0.4),
      border: OutlineInputBorder(
        borderRadius: AppShape.mediumRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppShape.mediumRadius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppShape.mediumRadius,
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: MaterialStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 40),
        textStyle: textTheme.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 40),
        textStyle: textTheme.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 40),
        textStyle: textTheme.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 40),
        textStyle: textTheme.labelLarge,
        shape: const StadiumBorder(),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
      elevation: 3,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
