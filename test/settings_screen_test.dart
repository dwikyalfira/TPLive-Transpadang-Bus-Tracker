import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transpadang_live/core/settings.dart';
import 'package:transpadang_live/features/settings/presentation/settings_screen.dart';
import 'package:transpadang_live/l10n/app_localizations.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  PackageInfo.setMockInitialValues(
    appName: 'TPLive',
    packageName: 'id.dwiky.transpadang_live',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  final container = ProviderContainer(
    overrides: [settingsStoreProvider.overrideWithValue(SettingsStore(prefs))],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('id'),
      home: SettingsScreen(),
    ),
  );
}

void main() {
  testWidgets('mode tema terpilih tersimpan', (tester) async {
    final container = await _container();
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('Terang'), findsOneWidget);
    expect(find.text('Gelap'), findsOneWidget);

    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();

    expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);
  });

  testWidgets('fitur warna dinamis tersedia', (tester) async {
    final container = await _container();
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    // Fitur sakelar warna dinamis dikembalikan ke UI.
    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets('tema tersimpan dalam preferensi (setelah restart app)',
      (tester) async {
    final container = await _container();
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();

    // Bangun ulang container seolah-olah aplikasi dibuka kembali: preferensi
    // yang tersimpan harus membuat mode gelap langsung aktif.
    final prefs = await SharedPreferences.getInstance();
    final reloaded = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(SettingsStore(prefs))],
    );
    addTearDown(reloaded.dispose);
    expect(reloaded.read(appSettingsProvider).themeMode, ThemeMode.dark);
  });

  testWidgets('bahasa & warna dinamis tersimpan', (tester) async {
    final container = await _container();
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(container.read(appSettingsProvider).locale, const Locale('en'));

    // Fitur sakelar warna dinamis dikembalikan; bisa diaktif/nonaktifkan.
    expect(find.byType(SwitchListTile), findsOneWidget);
    final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(switchTile.value, isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(container.read(appSettingsProvider).useDynamicColor, isFalse);

    expect(container.read(appSettingsProvider).locale, const Locale('en'));
  });
}
