import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/core/app_navigator.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/domain/bus_with_distance.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/floating_pinned_bus_card.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/halte_timeline_sheet.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/pinned_bus_overlay.dart';
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

List<Override> _overrides({
  String? followed,
  String? selectedCorridor,
  LatLng userLocation = const LatLng(-0.90, 100.30),
}) =>
    [
      busesProvider.overrideWith((ref) => Stream.value([_pinnedBus()])),
      halteDatasetProvider.overrideWith((ref) => _dataset()),
      followedBusProvider.overrideWith((ref) => followed),
      selectedCorridorProvider.overrideWith((ref) => selectedCorridor),
      userLocationProvider.overrideWith((ref) => Stream.value(userLocation)),
    ];

double _cardHeight(WidgetTester tester) =>
    tester.getSize(find.byKey(FloatingPinnedBusCard.contentKey)).height;

/// Meniru susunan di [MaterialApp.builder]: overlay dipasang di atas Navigator.
Widget _app({
  String? followed,
  String? selectedCorridor,
  LatLng userLocation = const LatLng(-0.90, 100.30),
  bool scrollableHome = false,
  ProviderContainer? container,
  List<NavigatorObserver> observers = const [],
}) {
  final home = scrollableHome
      ? Scaffold(
          body: ListView.builder(
            itemCount: 40,
            itemBuilder: (context, i) => SizedBox(
              height: 80,
              child: Center(child: Text('item $i')),
            ),
          ),
        )
      : const Scaffold(body: Center(child: Text('halaman penyangga')));

  final app = MaterialApp(
    navigatorKey: appNavigatorKey,
    navigatorObservers: observers,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('id'),
    builder: (context, child) => RootOverlay(child: child ?? const SizedBox()),
    home: home,
  );

  if (container != null) {
    return UncontrolledProviderScope(
      container: container,
      child: app,
    );
  }
  return ProviderScope(
    overrides: _overrides(
      followed: followed,
      selectedCorridor: selectedCorridor,
      userLocation: userLocation,
    ),
    child: app,
  );
}

/// Sama seperti [_app], namun halaman berisi tombol yang membuka detail bus
/// (tanpa melalui ketukan kartu) — untuk menguji pin yang terjadi di dalam
/// halaman detail.
Widget _appWithDetailButton({String? followed}) {
  final item = BusWithDistance(
    bus: _pinnedBus(),
    distanceKm: 0,
    etaMinutes: null,
    resolvedHeading: 90,
  );

  return ProviderScope(
    overrides: _overrides(followed: followed),
    child: MaterialApp(
      navigatorKey: appNavigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('id'),
      builder: (context, child) =>
          RootOverlay(child: child ?? const SizedBox()),
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
  testWidgets('kartu melayang muncul dalam versi mini saat bus di-pin',
      (tester) async {
    await tester.pumpWidget(_app(followed: 'K3|57'));
    await tester.pumpAndSettle();

    // Default kartu = mini (hanya garis progres + label, tanpa status).
    expect(find.byType(FloatingPinnedBusCard), findsOneWidget);
    expect(_cardHeight(tester), lessThan(100));
    expect(find.text('Sedang di'), findsNothing);
    expect(find.text('Halte berikutnya'), findsNothing);
    expect(find.textContaining('halte lagi'), findsOneWidget);
  });

  testWidgets('tetap tampil walau koridor lain dipilih & halaman berganti',
      (tester) async {
    // Filter koridor K1 (berbeda dari bus yang di-pin, K3) — kartu harus tetap
    // tampil karena bus dicari dari seluruh bus, bukan bus terfilter.
    await tester.pumpWidget(
      _app(followed: 'K3|57', selectedCorridor: 'K1'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingPinnedBusCard), findsOneWidget);

    // Pindah ke halaman lain (push route) via navigator root.
    appNavigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('Halaman 2'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Halaman 2'), findsOneWidget);
    expect(find.byType(FloatingPinnedBusCard), findsOneWidget);
  });

  testWidgets('ketuk mini → melar, ketuk besar → detail (kartu disembunyikan)',
      (tester) async {
    await tester.pumpWidget(_app(followed: 'K3|57'));
    await tester.pumpAndSettle();

    // Mini oleh default.
    expect(_cardHeight(tester), lessThan(100));

    // Ketuk kartu → memelar besar (status tampil).
    await tester.tap(find.byKey(FloatingPinnedBusCard.contentKey));
    await tester.pumpAndSettle();
    expect(_cardHeight(tester), greaterThan(120));
    expect(find.text('Sedang di'), findsOneWidget);
    expect(find.text('Halte berikutnya'), findsOneWidget);

    // Ketuk kartu besar lagi → detail terbuka. Kartu melayang disembunyikan
    // karena isinya sudah ada di sheet dan hanya akan menutupi daftar halte.
    await tester.tap(find.text('Sedang di'));
    await tester.pumpAndSettle();

    expect(find.byType(HalteTimelineSheet), findsOneWidget);
    expect(find.byType(FloatingPinnedBusCard), findsNothing);

    // Tutup sheet dengan mengetuk area luar → kartu kembali, tetap mini.
    await tester.tapAt(const Offset(400, 50));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingPinnedBusCard), findsOneWidget);
    expect(_cardHeight(tester), lessThan(100));
  });

  testWidgets('pin melalui detail bus → kartu disembunyikan saat sheet terbuka',
      (tester) async {
    await tester.pumpWidget(_appWithDetailButton(followed: 'K3|57'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('buka detail'));
    await tester.pumpAndSettle();

    // Selama detail terbuka kartu tidak tampil sama sekali (bukan versi mati).
    expect(find.byType(HalteTimelineSheet), findsOneWidget);
    expect(find.byType(FloatingPinnedBusCard), findsNothing);

    // Tutup sheet → kartu kembali dan beristirahat mini.
    await tester.tapAt(const Offset(400, 50));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingPinnedBusCard), findsOneWidget);
    expect(_cardHeight(tester), lessThan(100));
  });

  testWidgets('gulir ke bawah maupun kembali ke atas tetap mini',
      (tester) async {
    await tester.pumpWidget(_app(followed: 'K3|57', scrollableHome: true));
    await tester.pumpAndSettle();

    // Mini oleh default; ketuk → melar.
    await tester.tap(find.byKey(FloatingPinnedBusCard.contentKey));
    await tester.pumpAndSettle();
    expect(_cardHeight(tester), greaterThan(120));

    // Gulir ke bawah → kembali mini.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(_cardHeight(tester), lessThan(100));

    // Gulir balik ke atas (puncak) → tetap mini (tidak otomatis memelar).
    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(_cardHeight(tester), lessThan(100));
  });

  testWidgets('pindah halaman → kartu kembali mini', (tester) async {
    final container =
        ProviderContainer(overrides: _overrides(followed: 'K3|57'));
    addTearDown(container.dispose);
    AppNavigatorObserver.onRouteChanged = () {
      container.read(pinnedCardCollapsedProvider.notifier).state = true;
    };
    addTearDown(() => AppNavigatorObserver.onRouteChanged = null);

    await tester.pumpWidget(_app(
      followed: 'K3|57',
      container: container,
      observers: [appNavigatorObserver],
    ));
    await tester.pumpAndSettle();

    // Mini oleh default → ketuk untuk memelar.
    expect(_cardHeight(tester), lessThan(100));
    await tester.tap(find.byKey(FloatingPinnedBusCard.contentKey));
    await tester.pumpAndSettle();
    expect(_cardHeight(tester), greaterThan(120));

    // Pindah halaman (push) → kartu kembali mini.
    appNavigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('Halaman 2'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Halaman 2'), findsOneWidget);
    expect(_cardHeight(tester), lessThan(100));

    // Kembali (pop) → tetap mini.
    appNavigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_cardHeight(tester), lessThan(100));
  });

  testWidgets('kartu tidak muncul bila tidak ada bus di-pin', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(FloatingPinnedBusCard), findsNothing);
  });

  testWidgets('kartu pin global tersembunyi saat bus dipilih di layar peta',
      (tester) async {
    final container = ProviderContainer(overrides: [
      ..._overrides(followed: 'K3|57'),
      mapBusSelectedProvider.overrideWith((ref) => true),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(followed: 'K3|57', container: container));
    await tester.pumpAndSettle();

    // Pilihan bus di peta → kartu pin global disembunyikan agar tidak menumpuk.
    expect(find.byType(FloatingPinnedBusCard), findsNothing);
  });

  testWidgets('kartu pin menampilkan estimasi bus datang ke lokasi pengguna',
      (tester) async {
    // Pengguna ~1 km di timur bus.
    await tester.pumpWidget(_app(
      followed: 'K3|57',
      userLocation: const LatLng(-0.90, 100.31),
    ));
    await tester.pumpAndSettle();

    // Mode mini (kartu beristirahat): estimasi sudah terlihat sebagai chip.
    expect(find.textContaining('mnt'), findsOneWidget);

    // Melar → baris lengkap di footer.
    await tester.tap(find.byKey(FloatingPinnedBusCard.contentKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('ke lokasi Anda'), findsOneWidget);
  });

  testWidgets('estimasi tetap ada walau pengguna di belakang bus',
      (tester) async {
    // Pengguna di barat bus. Arah gerak bus tidak lagi menyembunyikan estimasi
    // (dulu bisa hilang-muncul karena heading server + akurasi GPS berbeda).
    await tester.pumpWidget(_app(
      followed: 'K3|57',
      userLocation: const LatLng(-0.90, 100.29),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('mnt'), findsOneWidget);

    await tester.tap(find.byKey(FloatingPinnedBusCard.contentKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('ke lokasi Anda'), findsOneWidget);
  });

  testWidgets('tombol kecilkan mengembalikan kartu penuh ke mini tanpa unpin',
      (tester) async {
    final container =
        ProviderContainer(overrides: _overrides(followed: 'K3|57'));
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(followed: 'K3|57', container: container));
    await tester.pumpAndSettle();

    // Melar dulu.
    await tester.tap(find.byKey(FloatingPinnedBusCard.contentKey));
    await tester.pumpAndSettle();
    expect(_cardHeight(tester), greaterThan(120));

    // Chevron "kecilkan" → kembali mini, pin tetap.
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(_cardHeight(tester), lessThan(100));
    expect(find.byType(FloatingPinnedBusCard), findsOneWidget);
    expect(container.read(followedBusProvider), 'K3|57');
  });

  testWidgets('tombol tutup melepas pin bus', (tester) async {
    final container =
        ProviderContainer(overrides: _overrides(followed: 'K3|57'));
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(followed: 'K3|57', container: container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(FloatingPinnedBusCard.contentKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingPinnedBusCard), findsNothing);
    expect(container.read(followedBusProvider), isNull);
  });
}
