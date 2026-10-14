import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi tampilan & bahasa yang dipilih pengguna.
///
/// [themeMode] dan [locale] bernilai "ikut sistem" masing-masing lewat
/// [ThemeMode.system] dan [locale] `null`.
@immutable
class AppSettings {
  final ThemeMode themeMode;

  /// `null` = ikuti bahasa sistem.
  final Locale? locale;

  /// Bila benar, warna tema mengikuti wallpaper perangkat (Android 12+).
  final bool useDynamicColor;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.useDynamicColor = true,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool clearLocale = false,
    bool? useDynamicColor,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: clearLocale ? null : (locale ?? this.locale),
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
    );
  }
}

/// Pembungkus [SharedPreferences] khusus preferensi [AppSettings].
///
/// Dipisah dari provider supaya mudah di-override saat pengujian.
class SettingsStore {
  final SharedPreferences _prefs;

  const SettingsStore(this._prefs);

  static const _kThemeMode = 'settings.theme_mode';
  static const _kLocale = 'settings.locale';
  static const _kDynamicColor = 'settings.dynamic_color';

  AppSettings load() {
    final theme = _prefs.getString(_kThemeMode);
    final localeCode = _prefs.getString(_kLocale);
    return AppSettings(
      themeMode: switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      locale: (localeCode == null || localeCode.isEmpty)
          ? null
          : Locale(localeCode),
      useDynamicColor: _prefs.getBool(_kDynamicColor) ?? true,
    );
  }

  Future<void> saveThemeMode(ThemeMode mode) =>
      _prefs.setString(_kThemeMode, mode.name);

  Future<void> saveLocale(Locale? locale) =>
      _prefs.setString(_kLocale, locale?.languageCode ?? '');

  Future<void> saveDynamicColor(bool enabled) =>
      _prefs.setBool(_kDynamicColor, enabled);
}

/// Di-override di `main()` dengan instance yang sudah memuat [SharedPreferences].
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw UnimplementedError('settingsStoreProvider belum di-override'),
);

/// Sumber kebenaran preferensi aplikasi (tema, bahasa, warna dinamis).
class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsStoreProvider).load();

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(settingsStoreProvider).saveThemeMode(mode);
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale == null
        ? state.copyWith(clearLocale: true)
        : state.copyWith(locale: locale);
    await ref.read(settingsStoreProvider).saveLocale(locale);
  }

  Future<void> setUseDynamicColor(bool enabled) async {
    state = state.copyWith(useDynamicColor: enabled);
    await ref.read(settingsStoreProvider).saveDynamicColor(enabled);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);
