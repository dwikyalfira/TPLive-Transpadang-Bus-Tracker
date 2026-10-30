import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transpadang_live/core/settings.dart';
import 'package:transpadang_live/core/ui/reveal.dart';
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
import 'package:transpadang_live/features/trip/data/saved_places_store.dart';
import 'package:transpadang_live/features/trip/presentation/trip_providers.dart';
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

List<Override> _overrides(List<Bus> buses, {bool outsideHours = false}) => [
      settingsStoreProvider.overrideWithValue(SettingsStore(_prefs)),
      savedPlacesStoreProvider.overrideWithValue(SavedPlacesStore(_prefs)),
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
      outsideHoursProvider.overrideWith((ref) => Stream.value(outsideHours)),
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

ProviderContainer _container(List<Bus> buses, {bool outsideHours = false}) {
  final container = ProviderContainer(
    overrides: _overrides(buses, outsideHours: outsideHours),
  );
  addTearDown(container.dispose);
  return container;
}

/// Penanda halte yang benar-benar tergambar di peta (kunci `mapStop:<id>`).
Finder _stopMarkers() => find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('mapStop:'),
    );

/// Membuka baris penyaring koridor (tertutup secara default).
Future<void> _openFilter(WidgetTester tester) async {
  await tester.tap(find.byKey(MapScreen.filterToggleKey));
  await tester.pumpAndSettle();
}

/// Kotak kartu status "tidak melayani" (Material pembungkusnya, bukan isi
/// teksnya), dipakai untuk memeriksa letak/lebar kartu.
Rect _statusCardRect(WidgetTester tester) => tester.getRect(
      find
          .ancestor(
            of: find.byKey(MapScreen.outsideHoursIconKey),
            matching: find.byType(Material),
          )
          .first,
    );

/// Preferensi tiruan: layar peta membaca [appSettingsProvider] untuk gaya peta.
late SharedPreferences _prefs;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('peta menampilkan judul, penyaring koridor, & penanda bus',
      (tester) async {
    final container =
        _container([_bus('11', 'K1'), _bus('57', 'K3', lng: 100.32)]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Peta Jaringan'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);

    await _openFilter(tester);
    expect(find.widgetWithText(ChoiceChip, 'Semua'), findsOneWidget);
    // Koridor tampil sebagai ikon bulat (gaya sama dengan layar utama).
    expect(find.byType(CorridorIconButton), findsNWidgets(2));
    expect(find.text('K1'), findsOneWidget);
    expect(find.text('K3'), findsOneWidget);
    // Penanda menampilkan nomor bus.
    expect(find.text('11'), findsOneWidget);
    expect(find.text('57'), findsOneWidget);
  });

  testWidgets('penyaring koridor tertutup default & bisa dibuka-tutup',
      (tester) async {
    final container = _container([_bus('11', 'K1')]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    // Tertutup: tombol hanya berisi panah — tanpa titik warna & label koridor.
    expect(find.byType(CorridorIconButton), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Semua'), findsNothing);
    expect(find.text('Semua'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(MapScreen.filterToggleKey),
        matching: find.byType(Text),
      ),
      findsNothing,
    );

    await _openFilter(tester);
    expect(find.byType(CorridorIconButton), findsNWidgets(2));
    expect(find.widgetWithText(ChoiceChip, 'Semua'), findsOneWidget);

    // Ketuk tombol lagi → tertutup kembali.
    await _openFilter(tester);
    expect(find.byType(CorridorIconButton), findsNothing);
  });

  testWidgets('panah penyaring menunjuk ke samping, mengikuti arah buka',
      (tester) async {
    final container = _container([_bus('11', 'K1')]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    final chevron = find.descendant(
      of: find.byKey(MapScreen.filterToggleKey),
      matching: find.byType(AnimatedRotation),
    );

    // Kapsul membuka ke samping → chevron horizontal, bukan expand_more.
    expect(
      find.descendant(of: chevron, matching: find.byIcon(Icons.chevron_right)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byIcon(Icons.expand_less), findsNothing);

    // Tertutup: panah menunjuk ke kanan (ke arah daftar akan muncul).
    expect(tester.widget<AnimatedRotation>(chevron).turns, 0);

    await _openFilter(tester);
    // Terbuka: diputar 180° → menunjuk ke kiri (arah kapsul menyusut).
    expect(tester.widget<AnimatedRotation>(chevron).turns, 0.5);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('tombol penyaring menyaring koridor & meneruskannya ke a11y',
      (tester) async {
    final handle = tester.ensureSemantics();
    final container =
        _container([_bus('11', 'K1'), _bus('57', 'K3', lng: 100.32)]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    final toggle = find.byKey(MapScreen.filterToggleKey);
    expect(
      tester.getSemantics(toggle),
      containsSemantics(
          label: 'Saring koridor', value: 'Semua', isButton: true),
    );

    await _openFilter(tester);
    await tester.tap(find.text('K3'));
    await tester.pumpAndSettle();
    expect(container.read(mapCorridorProvider), 'K3');

    // Label tidak lagi terlihat di tombol, jadi koridor aktif hanya bisa
    // dibaca lewat nilai semantiknya.
    await _openFilter(tester);
    expect(
      find.descendant(of: toggle, matching: find.byType(Text)),
      findsNothing,
    );
    expect(
      tester.getSemantics(toggle),
      containsSemantics(label: 'Saring koridor', value: 'K3', isButton: true),
    );
    handle.dispose();
  });

  testWidgets('mengetuk peta menutup penyaring koridor', (tester) async {
    final container = _container([_bus('11', 'K1')]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    await _openFilter(tester);
    expect(find.byType(CorridorIconButton), findsNWidgets(2));

    await tester.tapAt(const Offset(700, 300));
    // flutter_map menunda onTap ~250 ms untuk membedakan dari ketuk-ganda.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(CorridorIconButton), findsNothing);
  });

  testWidgets('menggeser peta menutup penyaring koridor', (tester) async {
    final container = _container([_bus('11', 'K1')]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    await _openFilter(tester);
    expect(find.byType(CorridorIconButton), findsNWidgets(2));

    await tester.drag(find.byType(FlutterMap), const Offset(-120, -80));
    await tester.pumpAndSettle();

    expect(find.byType(CorridorIconButton), findsNothing);
  });

  testWidgets('penyaring koridor melayang di atas peta, bukan pita AppBar',
      (tester) async {
    final container = _container([_bus('11', 'K1')]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    // Peta menempati seluruh area di bawah AppBar (tidak ada pita 48dp).
    final mapRect = tester.getRect(find.byType(FlutterMap));
    final appBarRect = tester.getRect(find.byType(AppBar));
    expect(mapRect.top, closeTo(appBarRect.bottom, 1));

    // Tombol penyaring menumpuk tipis di tepi kiri-atas peta, bukan di AppBar.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byKey(MapScreen.filterToggleKey),
      ),
      findsNothing,
    );
    final toggleRect = tester.getRect(find.byKey(MapScreen.filterToggleKey));
    expect(toggleRect.top, greaterThan(mapRect.top));
    expect(toggleRect.top - mapRect.top, lessThan(24));
    expect(toggleRect.left - mapRect.left, lessThan(24));
  });

  testWidgets('kartu "tidak melayani" hanya tampil di luar jam operasional',
      (tester) async {
    final container = _container([_bus('11', 'K1')]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(MapScreen.outsideHoursCardKey), findsNothing);
  });

  testWidgets('kartu "tidak melayani" di bawah penyaring & tepinya sejajar',
      (tester) async {
    // Ukuran ponsel: kartu memenuhi lebar layar minus inset, jadi tepinya
    // seharusnya sejajar dengan kapsul penyaring.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = _container(const [], outsideHours: true);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    final card = find.byKey(MapScreen.outsideHoursCardKey);
    expect(card, findsOneWidget);
    expect(find.text('Sedang tidak melayani penumpang'), findsOneWidget);

    final cardRect = _statusCardRect(tester);
    final toggleRect = tester.getRect(find.byKey(MapScreen.filterToggleKey));

    // Jarak yang jelas di bawah kapsul penyaring — dulu hanya 8 dp sehingga
    // kartu terlihat menempel pada tombol bulat di kiri-atas peta.
    expect(cardRect.top - toggleRect.bottom, greaterThanOrEqualTo(12));
    // Tepi kiri sejajar dengan kapsul (dulu kartu memakai inset 16 vs 12).
    expect(cardRect.left, closeTo(toggleRect.left, 0.5));
    expect(cardRect.right, closeTo(400 - cardRect.left, 0.5));
    // Tidak menutupi AppBar.
    expect(
      cardRect.top,
      greaterThan(tester.getRect(find.byType(AppBar)).bottom),
    );
  });

  testWidgets('kartu "tidak melayani" menyusut di layar lebar', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = _container(const [], outsideHours: true);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    final cardRect = _statusCardRect(tester);
    final toggleRect = tester.getRect(find.byKey(MapScreen.filterToggleKey));
    // Di tablet/lanskap kartu tidak melebar jadi pita: lebarnya dibatasi 520
    // dan tetap menempel di kolom kiri seperti kapsul penyaring.
    expect(cardRect.width, lessThanOrEqualTo(520));
    expect(cardRect.left, closeTo(toggleRect.left, 0.5));
  });

  testWidgets('ikon status membuka & melipat teks, bukan tombol panah',
      (tester) async {
    final container = _container(const [], outsideHours: true);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    // Terbuka (default): teks lengkap tampil, ikon sudah jadi tombolnya.
    expect(find.byKey(MapScreen.outsideHoursCardKey), findsOneWidget);
    expect(find.byKey(MapScreen.outsideHoursIconKey), findsOneWidget);
    expect(find.text('Sedang tidak melayani penumpang'), findsOneWidget);
    expect(find.text('TransPadang beroperasi pukul 06.00–19.00 WIB.'),
        findsOneWidget);

    // Tidak ada tombol panah terpisah di dalam kartu: satu-satunya kontrol
    // adalah ikon bulan di ujung kirinya.
    final card = find.byKey(MapScreen.outsideHoursCardKey);
    expect(
      find.descendant(of: card, matching: find.byType(IconButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.byIcon(Icons.chevron_left)),
      findsNothing,
    );

    // Ketuk ikon → teks hilang, tinggal ikon 48 dp saja.
    await tester.tap(find.byKey(MapScreen.outsideHoursIconKey));
    await tester.pumpAndSettle();

    expect(container.read(mapStatusExpandedProvider), isFalse);
    expect(find.byKey(MapScreen.outsideHoursCardKey), findsNothing);
    expect(find.text('Sedang tidak melayani penumpang'), findsNothing);
    expect(find.textContaining('06.00'), findsNothing);

    // Ikon duduk di kolom yang sama dengan kapsul penyaring di atasnya, dan
    // ukurannya sama persis dengan tombol penyaring itu (48 dp).
    final iconRect = tester.getRect(find.byKey(MapScreen.outsideHoursIconKey));
    final toggleRect = tester.getRect(find.byKey(MapScreen.filterToggleKey));
    expect(iconRect.left, closeTo(toggleRect.left, 0.5));
    expect(iconRect.width, toggleRect.width);
    expect(iconRect.height, toggleRect.height);
    expect(iconRect.top, greaterThan(toggleRect.bottom));

    // Ketuk ikon lagi → teks lengkap kembali.
    await tester.tap(find.byKey(MapScreen.outsideHoursIconKey));
    await tester.pumpAndSettle();

    expect(container.read(mapStatusExpandedProvider), isTrue);
    expect(find.byKey(MapScreen.outsideHoursCardKey), findsOneWidget);
    expect(find.text('Sedang tidak melayani penumpang'), findsOneWidget);
  });

  testWidgets('mengetuk peta menyembunyikan teks status', (tester) async {
    final container = _container(const [], outsideHours: true);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Sedang tidak melayani penumpang'), findsOneWidget);

    // Ketuk area peta yang kosong (di bawah kartu status).
    await tester.tapAt(const Offset(400, 400));
    // flutter_map menunda onTap ~250 ms untuk membedakan dari ketuk-ganda.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(container.read(mapStatusExpandedProvider), isFalse);
    expect(find.byKey(MapScreen.outsideHoursCardKey), findsNothing);
    expect(find.text('Sedang tidak melayani penumpang'), findsNothing);
    // Ikonnya tetap ada untuk membuka lagi.
    expect(find.byKey(MapScreen.outsideHoursIconKey), findsOneWidget);
  });

  testWidgets('menggeser/mencubit peta menyembunyikan teks status',
      (tester) async {
    final container = _container(const [], outsideHours: true);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Sedang tidak melayani penumpang'), findsOneWidget);

    // Geseran jari (bukan perubahan kamera terprogram) melipat kartu, sama
    // seperti baris penyaring koridor.
    await tester.drag(find.byType(FlutterMap), const Offset(-120, -80));
    await tester.pumpAndSettle();

    expect(container.read(mapStatusExpandedProvider), isFalse);
    expect(find.byKey(MapScreen.outsideHoursCardKey), findsNothing);
    expect(find.byKey(MapScreen.outsideHoursIconKey), findsOneWidget);
  });

  testWidgets('animasi kartu status sama dengan kapsul penyaring koridor',
      (tester) async {
    final container = _container(const [], outsideHours: true);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    // Kapsul penyaring & kartu status sama-sama memakai RevealRow; ambil
    // keduanya lewat keturunannya agar tidak tertukar.
    final filterReveal = tester.widget<RevealRow>(find
        .ancestor(
          of: find.byKey(MapScreen.filterToggleKey),
          matching: find.byType(RevealRow),
        )
        .first);
    final statusReveal = tester.widget<RevealRow>(find
        .ancestor(
          of: find.byKey(MapScreen.outsideHoursIconKey),
          matching: find.byType(RevealRow),
        )
        .first);

    expect(statusReveal.duration, filterReveal.duration);
    expect(statusReveal.curve, filterReveal.curve);
    expect(statusReveal.reverseCurve, filterReveal.reverseCurve);
  });

  testWidgets('isi kartu memudar masuk sebelum kartu terbuka penuh',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = _container(const [], outsideHours: true);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(MapScreen.outsideHoursIconKey));
    await tester.pumpAndSettle();
    expect(find.byKey(MapScreen.outsideHoursCardKey), findsNothing);

    // Tengah animasi membuka: isi sudah ada di pohon (jadi bisa memudar),
    // tetapi belum selebar kartu penuh — inilah yang membuat transisinya halus.
    await tester.tap(find.byKey(MapScreen.outsideHoursIconKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final midRect = _statusCardRect(tester);
    expect(find.byKey(MapScreen.outsideHoursCardKey), findsOneWidget);
    expect(midRect.width, lessThan(400 - 24));

    await tester.pumpAndSettle();
    expect(_statusCardRect(tester).width, closeTo(400 - 24, 0.5));
  });

  testWidgets('status terlipat tetap terbaca pembaca layar', (tester) async {
    final handle = tester.ensureSemantics();
    final container = _container(const [], outsideHours: true);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(MapScreen.outsideHoursIconKey));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(MapScreen.outsideHoursIconKey)),
      containsSemantics(
        label: 'Sedang tidak melayani penumpang',
        value: 'TransPadang beroperasi pukul 06.00–19.00 WIB.',
        isButton: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('penanda menampilkan panah arah hanya saat heading tersedia',
      (tester) async {
    final container = _container(
        [_bus('11', 'K1', heading: 90), _bus('57', 'K3', lng: 100.32)]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    // Hanya bus dengan heading yang punya panah arah.
    expect(find.byIcon(Icons.navigation), findsOneWidget);
  });

  testWidgets('mengetuk ikon koridor menyaring penanda bus', (tester) async {
    final container =
        _container([_bus('11', 'K1'), _bus('57', 'K3', lng: 100.32)]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    await _openFilter(tester);
    await tester.tap(find.text('K3'));
    await tester.pumpAndSettle();

    // Filter peta sendiri yang berubah; tab beranda tidak tersentuh.
    expect(container.read(mapCorridorProvider), 'K3');
    expect(container.read(selectedCorridorProvider), isNull);
    expect(find.text('11'), findsNothing);
    expect(find.text('57'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Semua'));
    await tester.pumpAndSettle();
    expect(container.read(mapCorridorProvider), isNull);
    expect(find.text('11'), findsOneWidget);
  });

  testWidgets('halte tampil saat koridor dipilih & ketuk membuka info',
      (tester) async {
    final container = _container(const []);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    // Tab "Semua": puluhan halte terlalu padat, jadi disembunyikan dulu.
    expect(_stopMarkers(), findsNothing);

    await _openFilter(tester);
    await tester.tap(find.text('K1'));
    await tester.pumpAndSettle();

    // Dua halte K1 (A & B) tampil; halte K3 tidak ikut.
    expect(_stopMarkers(), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('mapStop:b#1')));
    await tester.pumpAndSettle();

    expect(find.text('B'), findsOneWidget);
    expect(find.text('Dilayani oleh'), findsOneWidget);
    // Ikon papan halte (bukan ikon bus) menandai sheet halte.
    expect(find.byIcon(Icons.departure_board), findsOneWidget);
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
    final container =
        _container([_bus('11', 'K1'), _bus('57', 'K3', lng: 100.32)]);
    await tester.pumpWidget(_app(container, const MapScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('11'));
    await tester.pumpAndSettle();
    expect(find.byType(PinnedBusCardBody), findsOneWidget);

    await _openFilter(tester);
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
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
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
    final appBarMapButton = find.widgetWithIcon(IconButton, Icons.map_outlined);
    expect(appBarMapButton, findsOneWidget);
    expect(find.text('Lihat peta'), findsNothing);

    await tester.tap(appBarMapButton);
    await tester.pumpAndSettle();

    expect(find.text('Peta Jaringan'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('peta dari beranda mewarisi koridor tab yang aktif',
      (tester) async {
    final container =
        _container([_bus('11', 'K1'), _bus('57', 'K3', lng: 100.32)]);
    await tester.pumpWidget(_app(container, const HomeScreen()));
    await tester.pumpAndSettle();

    // Pindah ke tab K3 di beranda, lalu buka peta.
    await tester.tap(find.text('K3', skipOffstage: false).first);
    await tester.pumpAndSettle();
    expect(container.read(selectedCorridorProvider), 'K3');

    await tester.tap(find.widgetWithIcon(IconButton, Icons.map_outlined));
    await tester.pumpAndSettle();

    // Filter peta mulai dari koridor tab beranda; beranda tidak berubah.
    expect(container.read(mapCorridorProvider), 'K3');
    expect(container.read(selectedCorridorProvider), 'K3');
    expect(find.text('57'), findsOneWidget);
  });

  testWidgets('peta dibuka dengan bus fokus: hanya koridornya + kartu tampil',
      (tester) async {
    final container =
        _container([_bus('11', 'K1'), _bus('57', 'K3', lng: 100.32)]);
    await tester.pumpWidget(
      _app(container, const MapScreen(focusBusKey: 'K1|11')),
    );
    await tester.pumpAndSettle();

    // Peta dipersempit ke koridor bus fokus (chip filter juga ikut K1).
    expect(container.read(mapCorridorProvider), 'K1');
    // Tab beranda tidak ikut berpindah.
    expect(container.read(selectedCorridorProvider), isNull);
    // Bus koridor lain tidak digambar.
    expect(find.text('57'), findsNothing);

    // Bus fokus langsung terpilih, kartunya terbuka, dan penandanya disorot.
    expect(find.byType(PinnedBusCardBody), findsOneWidget);
    expect(container.read(mapBusSelectedProvider), isTrue);
    expect(find.byKey(const Key('busMarkerHighlight')), findsOneWidget);
  });

  testWidgets('bus fokus mengganti filter yang menyembunyikannya',
      (tester) async {
    final container =
        _container([_bus('11', 'K1'), _bus('57', 'K3', lng: 100.32)]);
    container.read(mapCorridorProvider.notifier).state = 'K3';

    await tester.pumpWidget(
      _app(container, const MapScreen(focusBusKey: 'K1|11')),
    );
    await tester.pumpAndSettle();

    // Filter pindah ke koridor bus fokus, dan pilihan tidak langsung batal.
    expect(container.read(mapCorridorProvider), 'K1');
    expect(find.byType(PinnedBusCardBody), findsOneWidget);
    expect(container.read(mapBusSelectedProvider), isTrue);
  });
}
