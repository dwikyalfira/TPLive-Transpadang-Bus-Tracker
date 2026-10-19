import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/bus_source.dart';
import 'package:transpadang_live/features/tracking/data/corridor_route.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/presentation/home_screen.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/corridor_selector.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/floating_pinned_bus_card.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/follow_bus_button.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/halte_timeline_sheet.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/map/map_screen.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/speed_dial.dart';
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

Bus _bus(String number, String corridor,
        {double? heading, double lng = 100.31}) =>
    Bus(
      number: number,
      lat: -0.90,
      lng: lng,
      corridor: corridor,
      route: 'A - B',
      heading: heading,
      speedKmh: 20,
      lastUpdate: DateTime.now().toUtc(),
    );

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

/// Penyedia ubin palsu: mengembalikan satu piksel transparan tanpa jaringan.
class _FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

List<Override> _overrides(List<Bus> buses) => [
      busSourceProvider.overrideWithValue(_SilentBusSource()),
      halteDatasetProvider.overrideWith((ref) => _dataset()),
      // Tanpa geometri mengikuti jalan: uji jatuh ke garis antar-halte.
      corridorRouteDatasetProvider
          .overrideWith((ref) async => const CorridorRouteDataset({})),
      manualCorridorRouteProvider
          .overrideWith((ref) async => const CorridorRouteDataset({})),
      userLocationProvider.overrideWith(
        (ref) => Stream.value(const LatLng(-0.90, 100.30)),
      ),
      busesProvider.overrideWith((ref) => Stream.value(buses)),
      // Timer periodik dihindari agar pengujian tidak meninggalkan timer aktif.
      outsideHoursProvider.overrideWith((ref) => Stream.value(false)),
      tileProviderProvider.overrideWithValue(_FakeTileProvider()),
    ];

Widget _app(ProviderContainer container, Widget home) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('id'),
      home: home,
    ),
  );
}

ProviderContainer _container(List<Bus> buses) {
  final container = ProviderContainer(overrides: _overrides(buses));
  addTearDown(container.dispose);
  return container;
}

void main() {
  testWidgets('peta menampilkan judul, penyaring koridor, & penanda bus',
      (tester) async {
    final container = _container([_bus('11', 'K1'), _bus('57', 'K3', lng: 100.32)]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Peta Jaringan'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Semua'), findsOneWidget);
    // Koridor tampil sebagai ikon bulat (gaya sama dengan layar utama).
    expect(find.byType(CorridorIconButton), findsNWidgets(2));
    expect(find.text('K1'), findsOneWidget);
    expect(find.text('K3'), findsOneWidget);
    // Penanda menampilkan nomor bus.
    expect(find.text('11'), findsOneWidget);
    expect(find.text('57'), findsOneWidget);
  });

  testWidgets('penanda menampilkan panah arah hanya saat heading tersedia',
      (tester) async {
    final container =
        _container([_bus('11', 'K1', heading: 90), _bus('57', 'K3', lng: 100.32)]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    // Hanya bus dengan heading yang punya panah arah.
    expect(find.byIcon(Icons.navigation), findsOneWidget);
  });

  testWidgets('mengetuk ikon koridor menyaring penanda bus', (tester) async {
    final container = _container([_bus('11', 'K1'), _bus('57', 'K3', lng: 100.32)]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('K3'));
    await tester.pumpAndSettle();

    expect(container.read(selectedCorridorProvider), 'K3');
    expect(find.text('11'), findsNothing);
    expect(find.text('57'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Semua'));
    await tester.pumpAndSettle();
    expect(find.text('11'), findsOneWidget);
  });

  testWidgets('ketuk penanda menampilkan kartu bawah, bukan detail',
      (tester) async {
    final container = _container([_bus('11', 'K1')]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('11'));
    await tester.pumpAndSettle();

    expect(find.byType(PinnedBusCardBody), findsOneWidget);
    expect(find.byType(HalteTimelineSheet), findsNothing);
    // Kartu bergaya kartu pin: status halte + rincian ala detail bus.
    expect(find.text('Sedang di'), findsOneWidget);
    expect(find.text('Halte berikutnya'), findsOneWidget);
    expect(find.byType(BusSpeedDial), findsOneWidget);
  });

  testWidgets('tombol tutup menyembunyikan kartu bus', (tester) async {
    final container = _container([_bus('11', 'K1')]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('11'));
    await tester.pumpAndSettle();
    expect(find.byType(PinnedBusCardBody), findsOneWidget);

    final closeOnCard = find.descendant(
      of: find.byType(PinnedBusCardBody),
      matching: find.byIcon(Icons.close),
    );
    await tester.tap(closeOnCard);
    await tester.pumpAndSettle();

    expect(find.byType(PinnedBusCardBody), findsNothing);
  });

  testWidgets('ganti penyaring koridor menutup kartu bus', (tester) async {
    final container = _container([_bus('11', 'K1'), _bus('57', 'K3', lng: 100.32)]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('11'));
    await tester.pumpAndSettle();
    expect(find.byType(PinnedBusCardBody), findsOneWidget);

    await tester.tap(find.text('K3'));
    await tester.pumpAndSettle();

    expect(find.byType(PinnedBusCardBody), findsNothing);
  });

  testWidgets('ketuk kartu bus membuka detail halte', (tester) async {
    final container = _container([_bus('11', 'K1')]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('11'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PinnedBusCardBody));
    await tester.pumpAndSettle();

    expect(find.byType(HalteTimelineSheet), findsOneWidget);
  });

  testWidgets('ketuk area kosong peta menutup kartu bus', (tester) async {
    final container = _container([_bus('11', 'K1')]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('11'));
    await tester.pumpAndSettle();
    expect(find.byType(PinnedBusCardBody), findsOneWidget);

    await tester.tapAt(const Offset(700, 200));
    // flutter_map menunda onTap ~250 ms untuk membedakan dari ketuk-ganda.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(PinnedBusCardBody), findsNothing);
  });

  testWidgets('kartu peta punya tombol pin & bisa mengikuti bus',
      (tester) async {
    const channel = MethodChannel('id.dwiky.transpadang_live/follow');
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'requestNotificationPermission':
          return true;
        default:
          return null;
      }
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    final container = _container([_bus('11', 'K1')]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('11'));
    await tester.pumpAndSettle();
    expect(find.byType(FollowBusButton), findsOneWidget);

    // Pin bus → ikuti via notifikasi; pilihan peta menandai provider agar kartu
    // pin global tidak menumpuk.
    await tester.tap(find.byType(FollowBusButton));
    await tester.pumpAndSettle();

    expect(container.read(followedBusProvider), 'K1|11');
    expect(container.read(mapBusSelectedProvider), isTrue);
    expect(calls, contains('startFollow'));

    // Ketuk lagi → berhenti mengikuti.
    await tester.tap(find.byType(FollowBusButton));
    await tester.pumpAndSettle();

    expect(container.read(followedBusProvider), isNull);
    expect(calls, contains('stopFollow'));
  });

  testWidgets('ikon peta di AppBar membuka layar peta', (tester) async {
    final container = _container([_bus('11', 'K1')]);
    await tester.pumpWidget(_app(container, const HomeScreen()));
    await tester.pumpAndSettle();

    // Satu-satunya pintu masuk peta: ikon di AppBar (tanpa tombol di kartu).
    final appBarMapButton =
        find.widgetWithIcon(IconButton, Icons.map_outlined);
    expect(appBarMapButton, findsOneWidget);
    expect(find.text('Lihat peta'), findsNothing);

    await tester.tap(appBarMapButton);
    await tester.pumpAndSettle();

    expect(find.text('Peta Jaringan'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('peta dibuka dengan bus fokus: kartu langsung tampil', (tester) async {
    final container =
        _container([_bus('11', 'K1'), _bus('57', 'K3', lng: 100.32)]);
    await tester.pumpWidget(
      _app(container, const MapScreen(focusBusKey: 'K1|11')),
    );
    await tester.pumpAndSettle();

    // Bus fokus langsung terpilih & kartunya terbuka.
    expect(find.byType(PinnedBusCardBody), findsOneWidget);
    expect(container.read(mapBusSelectedProvider), isTrue);

    // Filter "Semua" dibiarkan agar tab di layar utama tidak ikut berpindah.
    expect(container.read(selectedCorridorProvider), isNull);
  });

  testWidgets('bus fokus hanya mengubah filter bila tersaring keluar',
      (tester) async {
    final container =
        _container([_bus('11', 'K1'), _bus('57', 'K3', lng: 100.32)]);
    container.read(selectedCorridorProvider.notifier).state = 'K3';

    await tester.pumpWidget(
      _app(container, const MapScreen(focusBusKey: 'K1|11')),
    );
    await tester.pumpAndSettle();

    // Filter pindah ke koridor bus fokus, dan pilihan tidak langsung batal.
    expect(container.read(selectedCorridorProvider), 'K1');
    expect(find.byType(PinnedBusCardBody), findsOneWidget);
    expect(container.read(mapBusSelectedProvider), isTrue);
  });
}
