import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/core/app_navigator.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/domain/bus_with_distance.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/halte_timeline_sheet.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/pinned_bus_overlay.dart';
import 'package:transpadang_live/features/trip/domain/trip_endpoint.dart';
import 'package:transpadang_live/features/trip/presentation/trip_providers.dart';
import 'package:transpadang_live/l10n/app_localizations.dart';

Halte _h(double lat, double lng, String nama) =>
    Halte(nama: nama, pos: LatLng(lat, lng));

HalteDataset _dataset() {
  final k3 = CorridorStops(kode: 'K3', arah: {
    'pergi': CorridorDirection(label: 'D - A', halte: [
      _h(-0.90, 100.30, 'TK Aisyiah Lelongkaran'),
      _h(-0.90, 100.310, 'Masjid An-Nur'),
      _h(-0.90, 100.32, 'C'),
      _h(-0.90, 100.33, 'D'),
    ]),
    'pulang': CorridorDirection(label: 'A - D', halte: [
      _h(-0.90, 100.33, 'D'),
      _h(-0.90, 100.32, 'C'),
      _h(-0.90, 100.310, 'Masjid An-Nur'),
      _h(-0.90, 100.30, 'TK Aisyiah Lelongkaran'),
    ]),
  });
  return HalteDataset({'K3': k3});
}

/// Koridor dengan banyak halte agar timeline bisa benar-benar digulir.
HalteDataset _bigDataset() {
  final pergi = [for (var i = 0; i < 12; i++) _h(-0.90, 100.30 + i * 0.01, 'Halte $i')];
  final k3 = CorridorStops(kode: 'K3', arah: {
    'pergi': CorridorDirection(label: 'D - A', halte: pergi),
    'pulang': CorridorDirection(label: 'A - D', halte: pergi.reversed.toList()),
  });
  return HalteDataset({'K3': k3});
}

Bus _pinnedBus() => Bus(
      number: '57',
      lat: -0.90,
      lng: 100.3005,
      corridor: 'K3',
      route: 'D - A',
      heading: 90,
      speedKmh: 20,
      lastUpdate: DateTime.now().toUtc(),
    );

TripEndpoint _halteEndpoint(String nama, double lat, double lng) =>
    TripEndpoint.halte(HalteEntry(halte: _h(lat, lng, nama), corridors: {'K3'}));

List<Override> _overrides({
  TripEndpoint? origin,
  TripEndpoint? destination,
  HalteDataset? dataset,
}) => [
  busesProvider.overrideWith((ref) => Stream.value([_pinnedBus()])),
  halteDatasetProvider.overrideWith((ref) => dataset ?? _dataset()),
  userLocationProvider.overrideWith(
    (ref) => Stream.value(const LatLng(-0.90, 100.30)),
  ),
  tripOriginEndpointProvider.overrideWith((ref) => origin ?? const TripEndpoint.gps()),
  tripDestinationEndpointProvider.overrideWith((ref) => destination),
];

Widget _app(List<Override> overrides) {
  final item = BusWithDistance(
    bus: _pinnedBus(),
    distanceKm: 0,
    etaMinutes: null,
    resolvedHeading: 90,
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      navigatorKey: appNavigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('id'),
      builder: (context, child) => RootOverlay(child: child ?? const SizedBox()),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBusTimeline(context, item),
              child: const Text('buka detail'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('segmen naik→turun ditandai & jumlah halte dipersempit',
      (tester) async {
    await tester.pumpWidget(_app(_overrides(
      origin: _halteEndpoint('TK Aisyiah Lelongkaran', -0.90, 100.30),
      destination: _halteEndpoint('C', -0.90, 100.32),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('buka detail'));
    await tester.pumpAndSettle();

    expect(find.text('Naik'), findsOneWidget);
    expect(find.text('Turun'), findsOneWidget);
    expect(find.textContaining('dari 4 halte'), findsOneWidget);
  });

  testWidgets('tanpa asal/turun halte, timeline tetap menampilkan seluruh '
      'lintasan', (tester) async {
    await tester.pumpWidget(_app(_overrides()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('buka detail'));
    await tester.pumpAndSettle();

    expect(find.text('Naik'), findsNothing);
    expect(find.textContaining('dari 4 halte'), findsNothing);
  });

  testWidgets('asal GPS + tujuan halte → segmen tetap disorot dari rencana',
      (tester) async {
    await tester.pumpWidget(_app(_overrides(
      destination: _halteEndpoint('C', -0.90, 100.32),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('buka detail'));
    await tester.pumpAndSettle();

    expect(find.text('Naik'), findsOneWidget);
    expect(find.text('Turun'), findsOneWidget);
    expect(find.textContaining('dari 4 halte'), findsOneWidget);
  });

  testWidgets('detail bus adalah sheet berjenjang & menutup saat timeline '
      'ditarik turun', (tester) async {
    await tester.pumpWidget(_app(_overrides()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('buka detail'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(sheet.initialChildSize, 0.9);
    expect(sheet.minChildSize, 0.0);

    // Menarik timeline turun mengecilkan sheet hingga menutup tanpa jeda.
    await tester.drag(find.byType(ListView), const Offset(0, 700));
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsNothing);
  });

  testWidgets('detail bus menutup saat header di luar timeline ditarik turun',
      (tester) async {
    await tester.pumpWidget(_app(_overrides()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('buka detail'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('busSheetHeader')), findsOneWidget);

    // Menarik turun pada area header (di luar timeline) juga menutup sheet.
    await tester.drag(find.byKey(const Key('busSheetHeader')), const Offset(0, 700));
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsNothing);
  });

  testWidgets('swipe ke bawah cepat pada header langsung menutup sheet',
      (tester) async {
    await tester.pumpWidget(_app(_overrides()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('buka detail'));
    await tester.pumpAndSettle();

    // Fling pendek tapi cepat: harus menutup lewat kecepatan, tanpa perlu
    // menarik lebih dari separuh tinggi sheet lebih dulu.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('busSheetHeader'))),
    );
    var stamp = Duration.zero;
    for (var i = 0; i < 5; i++) {
      stamp += const Duration(milliseconds: 16);
      await gesture.moveBy(const Offset(0, 24), timeStamp: stamp);
      await tester.pump(const Duration(milliseconds: 16));
    }
    stamp += const Duration(milliseconds: 16);
    await gesture.up(timeStamp: stamp);
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsNothing);
  });

  testWidgets('detail bus tidak meluber saat sheet mengecil drastis',
      (tester) async {
    await tester.pumpWidget(_app(_overrides()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('buka detail'));
    await tester.pumpAndSettle();

    // Tarik turun bertahap di atas daftar; tiap langkah sheet mengecil. Konten
    // berada dalam satu scrollable sehingga harus ter-clip, bukan memicu
    // RenderFlex overflow ("overflowed by N pixels on the bottom").
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(ListView)));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('header tetap di atas saat timeline digulir', (tester) async {
    await tester.pumpWidget(_app(_overrides(dataset: _bigDataset())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('buka detail'));
    await tester.pumpAndSettle();

    final header = find.byKey(const Key('busSheetHeader'));
    final before = tester.getTopLeft(header).dy;

    // Gulir timeline ke atas (menampilkan halte berikutnya) — header yang dipin
    // harus tetap pada posisinya, hanya daftar halte yang bergerak.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(header).dy, closeTo(before, 0.5));
  });

  testWidgets('detail bus tidak tergeser ke bawah saat ada system insets',
      (tester) async {
    // Simulasikan status bar & navigation bar perangkat.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    tester.view.padding = const FakeViewPadding(
      top: 24 * 2.75,
      bottom: 48 * 2.75,
    );
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_overrides()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('buka detail'));
    await tester.pumpAndSettle();

    // Sheet harus menempati 90% dari tinggi penuh layar (menempel ke bawah)
    // dan tidak tergeser turun oleh SafeArea status bar.
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final sheet = tester.getRect(find.byType(DraggableScrollableSheet));
    expect(sheet.bottom, closeTo(size.height, 1));
    expect(sheet.top, lessThan(size.height * 0.1 + 6));
  });
}