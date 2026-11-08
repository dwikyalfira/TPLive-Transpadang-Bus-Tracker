import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transpadang_live/core/settings.dart';
import 'package:transpadang_live/features/onboarding/presentation/onboarding_screen.dart';
import 'package:transpadang_live/l10n/app_localizations.dart';

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(appSettingsProvider).onboardingDone;
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('id'),
      home: done ? const Scaffold(body: Text('HOME')) : const OnboardingScreen(),
    );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Map<String, Object> initial,
) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [settingsStoreProvider.overrideWithValue(SettingsStore(prefs))],
  );
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(400 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const _Root()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('pemasangan baru menampilkan panduan', (tester) async {
    await _pump(tester, {});
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Lihat bus secara langsung'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('pengguna lama (sudah punya preferensi) tidak melihat panduan',
      (tester) async {
    await _pump(tester, {'settings.theme_mode': 'dark'});
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('Lewati langsung ke beranda dan menyimpan flag', (tester) async {
    final container = await _pump(tester, {});
    await tester.tap(find.byKey(OnboardingScreen.skipKey));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(container.read(appSettingsProvider).onboardingDone, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings.onboarding_done'), isTrue);
  });

  testWidgets('Lanjut melewati 3 layar lalu Mulai ke beranda', (tester) async {
    await _pump(tester, {});
    await tester.tap(find.byKey(OnboardingScreen.nextKey));
    await tester.pumpAndSettle();
    expect(find.text('Ikuti bus, tanpa repot'), findsOneWidget);
    await tester.tap(find.byKey(OnboardingScreen.nextKey));
    await tester.pumpAndSettle();
    expect(find.text('Aktifkan lokasi & notifikasi'), findsOneWidget);
    // Layar terakhir tidak menampilkan Lewati.
    expect(find.byKey(OnboardingScreen.enableKey), findsOneWidget);
    await tester.tap(find.byKey(OnboardingScreen.nextKey));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('mode ulang menutup layar tanpa mengubah preferensi',
      (tester) async {
    SharedPreferences.setMockInitialValues({'settings.theme_mode': 'dark'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(SettingsStore(prefs)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('id'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OnboardingScreen(replay: true),
                  ),
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.tap(find.byKey(OnboardingScreen.skipKey));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(prefs.getBool('settings.onboarding_done'), isNull);
  });
}
