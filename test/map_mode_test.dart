import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transpadang_live/core/config.dart';
import 'package:transpadang_live/core/map_mode.dart';
import 'package:transpadang_live/core/settings.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/bus_source.dart';
import 'package:transpadang_live/features/tracking/data/corridor_route.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/map/map_screen.dart';
import 'package:transpadang_live/l10n/app_localizations.dart';

/// Sumber bus tanpa jaringan/timer.
class _SilentBusSource implements BusSource {
  @override
  Stream<List<Bus>> get busStream => const Stream<List<Bus>>.empty();

  @override
  Stream<ConnectionStatus> get statusStream =>
      const Stream<ConnectionStatus>.empty();

  @override
  void connect() {}

  @override
  void dispose() {}
}

/// Penyedia ubin palsu: satu piksel transparan, tanpa jaringan.
class _FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

Halte _h(String nama) => Halte(nama: nama, pos: const LatLng(-0.90, 100.30));

HalteDataset _dataset() => HalteDataset({
      'K1': CorridorStops(kode: 'K1', arah: {
        'pergi': CorridorDirection(label: 'A - B', halte: [
          _h('A'),
          _h('B'),
        ]),
      }),
    });

Bus _bus(String number) => Bus(
      number: number,
      lat: -0.90,
      lng: 100.31,
      corridor: 'K1',
      route: 'A - B',
      heading: 90,
      speedKmh: 20,
      lastUpdate: DateTime.now().toUtc(),
    );

late SharedPreferences _prefs;

List<Override> _overrides(List<Bus> buses) => [
      settingsStoreProvider.overrideWithValue(SettingsStore(_prefs)),
      busSourceProvider.overrideWithValue(_SilentBusSource()),
      halteDatasetProvider.overrideWith((ref) => _dataset()),
      corridorRouteDatasetProvider
          .overrideWith((ref) async => const CorridorRouteDataset({})),
      manualCorridorRouteProvider
          .overrideWith((ref) async => const CorridorRouteDataset({})),
      userLocationProvider.overrideWith(
        (ref) => Stream.value(const LatLng(-0.90, 100.30)),
      ),
      busesProvider.overrideWith((ref) => Stream.value(buses)),
      outsideHoursProvider.overrideWith((ref) => Stream.value(false)),
      tileProviderProvider.overrideWithValue(_FakeTileProvider()),
    ];

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('id'),
        home: MapScreen(),
      ),
    );

ProviderContainer _container(List<Bus> buses) {
  final container = ProviderContainer(overrides: _overrides(buses));
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _prefs = await SharedPreferences.getInstance();
  });

  test('gaya peta tersimpan & terbaca ulang', () async {
    final container = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(SettingsStore(_prefs))],
    );
    addTearDown(container.dispose);

    expect(container.read(appSettingsProvider).mapMode, MapMode.theme);
    await container.read(appSettingsProvider.notifier).setMapMode(MapMode.satellite);
    expect(container.read(appSettingsProvider).mapMode, MapMode.satellite);

    // Container baru membaca ulang dari SharedPreferences yang sama.
    final reloaded = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(SettingsStore(_prefs))],
    );
    addTearDown(reloaded.dispose);
    expect(reloaded.read(appSettingsProvider).mapMode, MapMode.satellite);
  });

  test('mode tema diterjemahkan memakai kecerahan tema', () {
    expect(MapMode.theme.resolve(true), MapMode.dark);
    expect(MapMode.theme.resolve(false), MapMode.light);
    expect(MapMode.satellite.resolve(true), MapMode.satellite);
    expect(MapMode.light.resolve(true), MapMode.light);
  });

  test('tanpa token Mapbox semua gaya jatuh ke ubin OSM', () {
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore(_prefs)),
        mapboxTokenProvider.overrideWithValue(''),
      ],
    );
    addTearDown(container.dispose);

    for (final isDark in [true, false]) {
      final source = container.read(mapTileSourceProvider(isDark));
      expect(source.fromMapbox, isFalse);
      expect(source.urlTemplate, AppConfig.osmTileUrl);
    }
    // Tema gelap tanpa ubin gelap memakai filter warna.
    expect(container.read(mapTileSourceProvider(true)).needsDarkFilter, isTrue);
    expect(container.read(mapTileSourceProvider(false)).needsDarkFilter, isFalse);
  });

  test('dengan token Mapbox tiap gaya memakai style raster yang benar', () async {
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore(_prefs)),
        mapboxTokenProvider.overrideWithValue('pk.test'),
      ],
    );
    addTearDown(container.dispose);

    final light = container.read(mapTileSourceProvider(false));
    expect(light.fromMapbox, isTrue);
    expect(light.urlTemplate, contains(AppConfig.mapboxStreetsStyle));
    expect(light.needsDarkFilter, isFalse);

    final dark = container.read(mapTileSourceProvider(true));
    expect(dark.urlTemplate, contains(AppConfig.mapboxDarkStyle));
    expect(dark.needsDarkFilter, isFalse);

    await container
        .read(appSettingsProvider.notifier)
        .setMapMode(MapMode.satellite);
    expect(
      container.read(mapTileSourceProvider(false)).urlTemplate,
      contains(AppConfig.mapboxSatelliteStyle),
    );
  });


  testWidgets('menu gaya peta berisi 4 pilihan & bisa dipilih', (tester) async {
    final container = _container([_bus('11')]);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.layers_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(CheckedPopupMenuItem<MapMode>), findsNWidgets(4));
    expect(find.text('Ikuti tema'), findsOneWidget);
    expect(find.text('Terang'), findsOneWidget);
    expect(find.text('Gelap'), findsOneWidget);
    expect(find.text('Satelit'), findsOneWidget);

    await tester.tap(find.text('Gelap'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(container.read(appSettingsProvider).mapMode, MapMode.dark);
    // Pilihan tersimpan ke SharedPreferences, bukan hanya di memori.
    expect(_prefs.getString('settings.map_mode'), 'dark');
  });

  testWidgets('tombol fokus bus hanya tampil saat ada bus terpilih',
      (tester) async {
    final container = _container([_bus('11')]);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.center_focus_strong), findsNothing);

    // Mengetuk penanda bus memilihnya (kartu bus peta tampil).
    await tester.tap(find.text('11'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);

    // Mengetuk peta (bukan penanda) membatalkan pilihan.
    await tester.tapAt(const Offset(700, 200));
    // flutter_map menunda onTap ~250 ms untuk membedakan dari ketuk-ganda.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.center_focus_strong), findsNothing);
  });
}
