import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/l10n/app_localizations.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/domain/halte_tracker.dart';
import 'package:transpadang_live/features/tracking/domain/user_arrival.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/floating_pinned_bus_card.dart';

Halte _h(double lat, double lng, String nama) =>
    Halte(nama: nama, pos: LatLng(lat, lng));

HalteDataset _dataset() {
  final k3 = CorridorStops(kode: 'K3', arah: {
    'pergi': CorridorDirection(label: 'D - A', halte: [
      _h(-0.90, 100.30, 'TK Aisyiah Lelongkaran'),
      _h(-0.90, 100.31, 'Masjid An-Nur'),
      _h(-0.90, 100.32, 'C'),
      _h(-0.90, 100.33, 'D'),
    ]),
    'pulang': CorridorDirection(label: 'A - D', halte: [
      _h(-0.90, 100.33, 'D'),
      _h(-0.90, 100.32, 'C'),
      _h(-0.90, 100.31, 'Masjid An-Nur'),
      _h(-0.90, 100.30, 'TK Aisyiah Lelongkaran'),
    ]),
  });
  return HalteDataset({'K3': k3});
}

Bus _bus({double lng = 100.3005}) => Bus(
      number: '57',
      lat: -0.90,
      lng: lng,
      corridor: 'K3',
      route: 'D - A',
      heading: 90,
      speedKmh: 20,
      lastUpdate: DateTime.now().toUtc(),
    );

/// Menempatkan kartu di dalam [Stack] ukuran layar, seperti saat melayang
/// di atas peta.
Widget _host(
  Bus bus,
  HalteProgress progress, {
  bool collapsed = false,
  UserArrival? arrival,
  VoidCallback? onCollapse,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('id'),
    home: Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.grey)),
          FloatingPinnedBusCard(
            bus: bus,
            progress: progress,
            collapsed: collapsed,
            arrival: arrival,
            onCollapse: onCollapse,
            onClose: () {},
            footer: PinnedBusCardFooter(
              bus: bus,
              destinationLabel: progress.destinationLabel,
              arrival: arrival,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Estimasi "bus datang ke pengguna" untuk pengujian tampilan.
UserArrival _arrival({int minutes = 5, bool here = false}) => UserArrival(
      distanceKm: here ? 0.01 : 1.7,
      etaMinutes: here ? 0 : minutes,
    );

void main() {
  testWidgets('menampilkan status halte saat ini & berikutnya', (tester) async {
    await tester.pumpWidget(_host(_bus(), _progress()));

    expect(find.text('Sedang di'), findsOneWidget);
    expect(find.text('TK Aisyiah Lelongkaran'), findsOneWidget);
    expect(find.text('Halte berikutnya'), findsOneWidget);
    expect(find.text('Masjid An-Nur'), findsOneWidget);

    // Jarak & estimasi waktu berformat "<jarak> · ≈ <n> mnt".
    expect(
      find.textContaining(RegExp(r'\d+(\.\d+)? (m|km) .+ \d+ mnt')),
      findsOneWidget,
    );

    // Ikon status hijau & garis progres.
    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('menampilkan asal & tujuan pada garis progres', (tester) async {
    await tester.pumpWidget(_host(_bus(), _progress()));

    expect(find.textContaining('halte lagi'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
  });

  testWidgets('tombol tutup memanggil onClose', (tester) async {
    var closed = false;
    final progress = _progress();
    final bus = _bus();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('id'),
      home: Scaffold(
        body: Stack(
          children: [
            FloatingPinnedBusCard(
              bus: bus,
              progress: progress,
              onClose: () => closed = true,
            ),
          ],
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.close));
    expect(closed, isTrue);
  });

  testWidgets('kartu kompak, tidak memenuhi layar', (tester) async {
    // Ukuran viewport seperti ponsel (logical 360x800).
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(_bus(), _progress()));

    final size = tester.getSize(find.byKey(FloatingPinnedBusCard.contentKey));
    expect(size.height, lessThan(240));
    expect(size.width, lessThan(500));
  });

  testWidgets('mode ringkas menampilkan garis progres + label di bawahnya',
      (tester) async {
    await tester.pumpWidget(_host(_bus(), _progress(), collapsed: true));

    // Status & heading mode penuh tidak tampil.
    expect(find.text('Sedang di'), findsNothing);
    expect(find.text('Halte berikutnya'), findsNothing);

    // Label informasi di bawah garis progres tetap tampil.
    expect(find.textContaining('halte lagi'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);

    // Kartu tetap ada & tata letak jauh lebih pendek daripada mode penuh.
    final size = tester.getSize(find.byKey(FloatingPinnedBusCard.contentKey));
    expect(size.height, lessThan(120));
  });
  testWidgets('tombol kecilkan tampil di mode penuh dan memanggil onCollapse',
      (tester) async {
    var collapsed = false;
    await tester.pumpWidget(
      _host(_bus(), _progress(), onCollapse: () => collapsed = true),
    );

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    await tester.tap(find.byIcon(Icons.expand_more));
    expect(collapsed, isTrue);
  });

  testWidgets('tanpa onCollapse tidak ada tombol kecilkan', (tester) async {
    await tester.pumpWidget(_host(_bus(), _progress()));

    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('mode penuh menampilkan estimasi bus ke lokasi pengguna',
      (tester) async {
    await tester.pumpWidget(_host(_bus(), _progress(), arrival: _arrival()));

    // "≈ 5 mnt ke lokasi Anda · 1.7 km"
    expect(find.textContaining('≈ 5 mnt ke lokasi Anda'), findsOneWidget);
    expect(find.textContaining('1.7 km'), findsOneWidget);
  });

  testWidgets('mode ringkas menampilkan chip estimasi di kanan judul',
      (tester) async {
    await tester.pumpWidget(
      _host(_bus(), _progress(), collapsed: true, arrival: _arrival()),
    );

    expect(find.text('≈ 5 mnt'), findsOneWidget);
    // Kartu tetap ringkas (chip tidak menambah tinggi berarti).
    final size = tester.getSize(find.byKey(FloatingPinnedBusCard.contentKey));
    expect(size.height, lessThan(120));
  });

  testWidgets('bus yang sudah dekat disebut apa adanya', (tester) async {
    await tester.pumpWidget(
      _host(_bus(), _progress(),
          collapsed: true, arrival: _arrival(here: true)),
    );
    expect(find.text('sudah dekat'), findsOneWidget);

    await tester.pumpWidget(
      _host(_bus(), _progress(), arrival: _arrival(here: true)),
    );
    expect(find.text('Bus di sekitar lokasi Anda'), findsOneWidget);
  });
}

HalteProgress _progress() => HalteTracker.track(_bus(), _dataset())!;
