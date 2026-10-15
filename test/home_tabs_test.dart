import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transpadang_live/core/settings.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/data/trans_ws_datasource.dart';
import 'package:transpadang_live/features/tracking/presentation/home_screen.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/format.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/live_status_pill.dart';
import 'package:transpadang_live/l10n/app_localizations.dart';

Halte _h(double lat, double lng, String nama) =>
    Halte(nama: nama, pos: LatLng(lat, lng));

HalteDataset _dataset() {
  final k1 = CorridorStops(kode: 'K1', arah: {
    'pergi': CorridorDirection(label: 'A - B', halte: [
      _h(-0.90, 100.30, 'A'),
      _h(-0.90, 100.31, 'B'),
    ]),
  });
  final k3 = CorridorStops(kode: 'K3', arah: {
    'pergi': CorridorDirection(label: 'C - D', halte: [
      _h(-0.90, 100.30, 'C'),
      _h(-0.90, 100.31, 'D'),
    ]),
  });
  return HalteDataset({'K1': k1, 'K3': k3});
}

Bus _bus(String number, String corridor, {double lng = 100.30}) => Bus(
      number: number,
      lat: -0.90,
      lng: lng,
      corridor: corridor,
      route: 'A - B',
      heading: 90,
      speedKmh: 20,
      lastUpdate: DateTime.now().toUtc(),
    );
List<Override> _overrides(List<Bus> buses, {bool outsideHoursStatus = false}) =>
    [
      settingsStoreProvider.overrideWithValue(SettingsStore(_prefs)),
      halteDatasetProvider.overrideWith((ref) => _dataset()),
      userLocationProvider.overrideWith(
        (ref) => Stream.value(const LatLng(-0.90, 100.30)),
      ),
      busesProvider.overrideWith((ref) => Stream.value(buses)),
      // Penanda status luar jam operasional (jika true, UI menampilkan
      // penanda ungu dan menyembunyikan daftar bus; ini independen dari
      // waktu sebenarnya dan tidak memengaruhi koneksi socket).
      outsideHoursProvider.overrideWith((ref) => Stream.value(outsideHoursStatus)),
    ];

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('id'),
      home: HomeScreen(),
    ),
  );
}

ProviderContainer _container(List<Bus> buses) {
  final container = ProviderContainer(overrides: _overrides(buses));
  addTearDown(container.dispose);
  return container;
}

/// Ikon bulat koridor pada baris pemilih (teks "K1" juga muncul di badge kartu
/// bus, jadi carinya dibatasi pada ikon bulat berwarna koridor).
Finder _corridorIcon(String corridor) => find.ancestor(
      of: find.text(corridor, skipOffstage: false),
      matching: find.byWidgetPredicate(
        (widget) => widget is AnimatedContainer && widget.constraints?.maxWidth == 40,
      ),
    );

/// Warna latar ikon bulat koridor pada baris pemilih.
Color? _iconColor(WidgetTester tester, String corridor) =>
    (tester.widget<AnimatedContainer>(
      _corridorIcon(corridor),
    ).decoration as BoxDecoration)
        .color;

/// Preferensi palsu (in-memory) supaya layar utama bisa dibuat tanpa
/// SharedPreferences asli; nilai default = mode pengembangan mati.
late SharedPreferences _prefs;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('mode pengembangan default mati', (tester) async {
    final container = _container([_bus('11', 'K1', lng: 100.3005)]);
    // Mode demo telah dihapus secara lengkap dari aplikasi.
    container.dispose();
  });

  testWidgets('ikon koridor tampil & pilihan tersimpan saat diketuk',
      (tester) async {
    final container = _container([
      _bus('11', 'K1', lng: 100.3005),
      _bus('57', 'K3', lng: 100.3015),
    ]);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    // Chip "Semua" (awal) + satu ikon bulat per koridor yang punya bus.
    expect(find.widgetWithText(ChoiceChip, 'Semua'), findsOneWidget);
    expect(_corridorIcon('K1'), findsOneWidget);
    expect(_corridorIcon('K3'), findsOneWidget);

    // Warna ikon = warna koridornya (belum dipilih: versi transparan).
    expect(_iconColor(tester, 'K1'), corridorColor('K1').withOpacity(0.35));
    expect(_iconColor(tester, 'K3'), corridorColor('K3').withOpacity(0.35));

    // Halaman "Semua" berisi bus dari kedua koridor.
    expect(find.text('Bus 11'), findsOneWidget);
    expect(find.text('Bus 57'), findsOneWidget);

    // Ketuk ikon K1 → pindah ke K1 (sorot ikon ikut pindah, warna penuh).
    await tester.tap(find.text('K1', skipOffstage: false).first);
    await tester.pumpAndSettle();
    expect(container.read(selectedCorridorProvider), 'K1');
    expect(_iconColor(tester, 'K1'), corridorColor('K1'));

    await tester.tap(find.text('K3', skipOffstage: false).first);
    await tester.pumpAndSettle();
    expect(container.read(selectedCorridorProvider), 'K3');

    // Kembali ke "Semua".
    await tester.tap(find.widgetWithText(ChoiceChip, 'Semua'));
    await tester.pumpAndSettle();
    expect(container.read(selectedCorridorProvider), isNull);
  });

  testWidgets('geser layar berpindah tab', (tester) async {
    final container = _container([
      _bus('11', 'K1', lng: 100.3005),
      _bus('57', 'K3', lng: 100.3015),
    ]);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.byType(TabBarView), findsOneWidget);

    // Geser ke kiri: "Semua" → K1.
    await tester.fling(
      find.byType(TabBarView),
      const Offset(-500, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedCorridorProvider), 'K1');

    // Geser lagi ke kiri: K1 → K3.
    await tester.fling(
      find.byType(TabBarView),
      const Offset(-500, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedCorridorProvider), 'K3');

    // Geser ke kanan: kembali ke K1.
    await tester.fling(
      find.byType(TabBarView),
      const Offset(500, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedCorridorProvider), 'K1');
  });

  testWidgets('tanpa bus, hanya halaman "Semua" (tanpa TabBarView)',
      (tester) async {
    final container = _container(const <Bus>[]);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.byType(TabBarView), findsNothing);
    expect(find.text('Belum ada bus terdeteksi di sekitar Anda.'),
        findsOneWidget);
    expect(container.read(selectedCorridorProvider), isNull);
  });

  testWidgets('di luar jam operasional: penanda ungu, bus tidak tampil',
      (tester) async {
    final container = ProviderContainer(overrides: [
      ..._overrides([_bus('16', 'K3', lng: 100.3015)], outsideHoursStatus: true),
      // Layanan "sedang tidak tersedia" (ungu), namun data bus tetap masuk.
      connectionStatusProvider.overrideWith(
        (ref) => Stream.value(ConnectionStatus.outsideHours),
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    // Penanda di AppBar: ungu + teks "Layanan sedang tidak tersedia".
    final pillContext = tester.element(find.byType(LiveStatusPill));
    final (label, color) = LiveStatusPill.describe(
      ConnectionStatus.outsideHours,
      AppLocalizations.of(pillContext),
    );
    expect(color, const Color(0xFF7B1FA2));
    expect(label, 'Di luar jam operasional');
    expect(find.text('Di luar jam operasional'), findsOneWidget);

    // Daftar bus disembunyikan saat layanan tidak melayani penumpang.
    expect(find.text('Bus 16'), findsNothing);

    // Menampilkan informasi bahwa layanan sedang tidak melayani penumpang.
    expect(find.text('Sedang tidak melayani penumpang'), findsOneWidget);
  });
}
