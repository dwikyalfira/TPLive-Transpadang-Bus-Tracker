import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/domain/halte_tracker.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';
import 'package:transpadang_live/features/trip/data/geocoding_service.dart';
import 'package:transpadang_live/features/trip/data/saved_places_store.dart';
import 'package:transpadang_live/features/trip/presentation/trip_providers.dart';
import 'package:transpadang_live/features/trip/presentation/trip_screen.dart';
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

class _FakeGeocoder extends GeocodingService {
  @override
  Future<List<GeocodingResult>> search(
    String query, {
    int limit = 6,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    return const [
      GeocodingResult(
        name: 'Stadion Haji Agus Salim',
        displayName: 'Stadion Haji Agus Salim, Padang',
        pos: LatLng(-0.90, 100.33),
      ),
    ];
  }

  @override
  void close() {}
}

Widget _app() {
  return ProviderScope(
    overrides: [
      geocodingServiceProvider.overrideWithValue(_FakeGeocoder()),
      halteDatasetProvider.overrideWith((ref) => _dataset()),
      userLocationProvider.overrideWith(
        (ref) => Stream.value(const LatLng(-0.90, 100.30)),
      ),
      busesProvider.overrideWith((ref) => Stream.value(const <Bus>[])),
      savedPlacesStoreProvider.overrideWithValue(SavedPlacesStore(_prefs)),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('id'),
      home: TripScreen(),
    ),
  );
}

Bus _liveBus() => Bus(
      number: '57',
      lat: -0.90,
      lng: 100.305,
      corridor: 'K3',
      route: 'D - A',
      heading: 90,
      speedKmh: 20,
      lastUpdate: DateTime.now().toUtc(),
    );

Widget _appWithLiveBus() {
  final dataset = _dataset();
  final progress = HalteTracker.track(_liveBus(), dataset)!;
  final tripBus = TripBus(
    bus: _liveBus(),
    distanceKm: 0.5,
    etaMinutes: 3,
    progress: progress,
  );
  return ProviderScope(
    overrides: [
      geocodingServiceProvider.overrideWithValue(_FakeGeocoder()),
      halteDatasetProvider.overrideWith((ref) => dataset),
      userLocationProvider.overrideWith(
        (ref) => Stream.value(const LatLng(-0.90, 100.30)),
      ),
      busesProvider.overrideWith((ref) => Stream.value(const <Bus>[])),
      tripBusesProvider.overrideWith((ref, leg) => [tripBus]),
      savedPlacesStoreProvider.overrideWithValue(SavedPlacesStore(_prefs)),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('id'),
      home: TripScreen(),
    ),
  );
}

Widget _appWithLocationError() {
  return ProviderScope(
    overrides: [
      geocodingServiceProvider.overrideWithValue(_FakeGeocoder()),
      halteDatasetProvider.overrideWith((ref) => _dataset()),
      userLocationProvider.overrideWith(
        (ref) => Stream<LatLng>.error(
          const LocationException(LocationErrorKind.permissionDenied),
        ),
      ),
      busesProvider.overrideWith((ref) => Stream.value(const <Bus>[])),
      savedPlacesStoreProvider.overrideWithValue(SavedPlacesStore(_prefs)),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('id'),
      home: TripScreen(),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('halte ke halte: pilih tujuan dari daftar halte', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Awal: belum ada tujuan.
    expect(find.text('Pilih tujuan'), findsOneWidget);

    // Buka pemilih tujuan (default tab "Halte").
    await tester.tap(find.text('Pilih tujuan'));
    await tester.pumpAndSettle();

    // Daftar halte tampil; pilih halte D.
    expect(find.text('D'), findsWidgets);
    await tester.tap(find.text('D').first);
    await tester.pumpAndSettle();

    // Rute halte->halte dari lokasi GPS (nearest A) ke D.
    expect(find.textContaining('naik di A'), findsOneWidget);
    expect(find.textContaining('turun di D'), findsOneWidget);
    expect(find.textContaining('langsung'), findsOneWidget);
  });

  testWidgets('GPS error: tampil penjelasan & opsi pilih halte sebagai asal',
      (tester) async {
    await tester.pumpWidget(_appWithLocationError());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih tujuan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('D').first);
    await tester.pumpAndSettle();

    expect(find.text('Izin lokasi diperlukan'), findsOneWidget);
    expect(find.text('Pilih halte sebagai asal'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('cari tempat lalu tampilkan rute', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih tujuan'));
    await tester.pumpAndSettle();

    // Pindah ke tab "Tempat".
    await tester.tap(find.text('Tempat'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'stadion');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    expect(find.text('Stadion Haji Agus Salim'), findsOneWidget);
    await tester.tap(find.text('Stadion Haji Agus Salim'));
    await tester.pumpAndSettle();

    expect(find.textContaining('naik di A'), findsOneWidget);
    expect(find.textContaining('turun di D'), findsOneWidget);
  });

  testWidgets('kartu bus dapat diketuk (buka detail) dan diikuti',
      (tester) async {
    await tester.pumpWidget(_appWithLiveBus());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih tujuan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('D').first);
    await tester.pumpAndSettle();

    // Kartu bus tampil dengan tombol ikuti.
    expect(find.text('Bus 57'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);

    // Ketuk kartu → bottom sheet detail halte terbuka.
    await tester.tap(find.text('Bus 57'));
    await tester.pumpAndSettle();

    expect(find.text('Halte berikutnya'), findsOneWidget);
    expect(find.textContaining('halte'), findsWidgets);
  });
}
