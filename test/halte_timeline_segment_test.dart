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
}) => [
  busesProvider.overrideWith((ref) => Stream.value([_pinnedBus()])),
  halteDatasetProvider.overrideWith((ref) => _dataset()),
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
}