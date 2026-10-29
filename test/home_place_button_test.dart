import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';
import 'package:transpadang_live/features/trip/data/geocoding_service.dart';
import 'package:transpadang_live/features/trip/data/saved_places_store.dart';
import 'package:transpadang_live/features/trip/domain/saved_place.dart';
import 'package:transpadang_live/features/trip/presentation/location_picker_screen.dart';
import 'package:transpadang_live/features/trip/presentation/trip_providers.dart';
import 'package:transpadang_live/features/trip/presentation/trip_screen.dart';
import 'package:transpadang_live/features/trip/presentation/widgets/home_place_button.dart';
import 'package:transpadang_live/l10n/app_localizations.dart';

late SharedPreferences _prefs;

Halte _h(double lat, double lng, String nama) =>
    Halte(nama: nama, pos: LatLng(lat, lng));

HalteDataset _dataset() {
  final k3 = CorridorStops(kode: 'K3', arah: {
    'pergi': CorridorDirection(label: 'D - A', halte: [
      _h(-0.90, 100.30, 'A'),
      _h(-0.90, 100.31, 'B'),
      _h(-0.90, 100.32, 'C'),
      _h(-0.90, 100.33, 'D'),
    ]),
    'pulang': CorridorDirection(label: 'A - D', halte: [
      _h(-0.90, 100.33, 'D'),
      _h(-0.90, 100.32, 'C'),
      _h(-0.90, 100.31, 'B'),
      _h(-0.90, 100.30, 'A'),
    ]),
  });
  return HalteDataset({'K3': k3});
}

/// Pencarian tempat palsu: tidak ada panggilan jaringan di pengujian.
class _FakeGeocoder extends GeocodingService {
  @override
  Future<List<GeocodingResult>> search(
    String query, {
    int limit = 6,
    Duration timeout = const Duration(seconds: 12),
  }) async =>
      const [];

  @override
  void close() {}
}

/// Lokasi rumah contoh yang sudah tersimpan.
SavedPlace _home() => const SavedPlace(
      kind: SavedPlaceKind.halte,
      label: 'Rumah',
      lat: -0.90,
      lng: 100.31,
      corridors: 'K3',
    );

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      savedPlacesStoreProvider.overrideWithValue(SavedPlacesStore(_prefs)),
      geocodingServiceProvider.overrideWithValue(_FakeGeocoder()),
      halteDatasetProvider.overrideWith((ref) => _dataset()),
      userLocationProvider.overrideWith(
        (ref) => Stream.value(const LatLng(-0.90, 100.30)),
      ),
      busesProvider.overrideWith((ref) => Stream.value(const <Bus>[])),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Tombol dipasang di baris yang sama dengan bilah pencarian (seperti di
/// beranda), bukan sebagai kartu selebar layar.
Widget _app(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('id'),
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: SizedBox(height: 48)),
                SizedBox(width: 8),
                HomePlaceButton(),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('tombol kosong memakai ikon rumah bergaris', (tester) async {
    await tester.pumpWidget(_app(_container()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.home), findsNothing);
    // Ringkas: tidak ada teks panjang seperti kartu sebelumnya.
    expect(find.text('Rute ke rumah'), findsNothing);
  });

  testWidgets('mengetuk tombol membuka pemilih lokasi rumah', (tester) async {
    await tester.pumpWidget(_app(_container()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(HomePlaceButton));
    await tester.pumpAndSettle();

    expect(find.byType(LocationPickerScreen), findsOneWidget);
    expect(find.text('Pilih lokasi rumah'), findsOneWidget);
  });

  testWidgets('memilih halte menyimpan lokasi rumah & ikon jadi terisi',
      (tester) async {
    final container = _container();
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(HomePlaceButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').first);
    await tester.pumpAndSettle();

    final home = container.read(savedPlacesProvider).home;
    expect(home, isNotNull);
    expect(home!.label, 'B');
    expect(home.corridors, contains('K3'));
    // Persist ke SharedPreferences, bukan hanya state di memori.
    expect(_prefs.getString('saved.home'), isNotNull);

    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
  });

  testWidgets('mengetuk tombol membuka perencana dengan tujuan lokasi rumah',
      (tester) async {
    final container = _container();
    await container.read(savedPlacesProvider.notifier).setHome(_home());

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(HomePlaceButton));
    await tester.pumpAndSettle();

    expect(find.byType(TripScreen), findsOneWidget);
    final destination = container.read(tripDestinationEndpointProvider);
    expect(destination, isNotNull);
    expect(destination!.label, 'Rumah');
    expect(container.read(tripOriginEndpointProvider).isGps, isTrue);
  });

  testWidgets('tekan lama menampilkan menu ubah & hapus', (tester) async {
    final container = _container();
    await container.read(savedPlacesProvider.notifier).setHome(_home());

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(HomePlaceButton));
    await tester.pumpAndSettle();

    expect(find.text('Ubah lokasi rumah'), findsOneWidget);
    expect(find.text('Hapus lokasi rumah'), findsOneWidget);
  });

  testWidgets('hapus lewat menu mengosongkan slot dan bisa diurungkan',
      (tester) async {
    final container = _container();
    await container.read(savedPlacesProvider.notifier).setHome(_home());

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(HomePlaceButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus lokasi rumah'));
    await tester.pumpAndSettle();

    expect(container.read(savedPlacesProvider).home, isNull);
    expect(_prefs.getString('saved.home'), isNull);
    expect(find.text('Lokasi rumah dihapus.'), findsOneWidget);

    await tester.tap(find.text('Urungkan'));
    await tester.pumpAndSettle();

    expect(container.read(savedPlacesProvider).home?.label, 'Rumah');
    expect(find.byIcon(Icons.home), findsOneWidget);
  });

  testWidgets('ubah lewat menu membuka pemilih lokasi', (tester) async {
    final container = _container();
    await container.read(savedPlacesProvider.notifier).setHome(_home());

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(HomePlaceButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah lokasi rumah'));
    await tester.pumpAndSettle();

    expect(find.byType(LocationPickerScreen), findsOneWidget);
  });
}
