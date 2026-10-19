import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/corridor_info_header.dart';
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

Bus _bus() => Bus(
      number: '57',
      lat: -0.90,
      lng: 100.30,
      corridor: 'K3',
      route: 'C - D',
      heading: 90,
      speedKmh: 20,
      lastUpdate: DateTime.now().toUtc(),
    );

Widget _app() => ProviderScope(
      overrides: [
        busesProvider.overrideWith((ref) => Stream.value([_bus()])),
        halteDatasetProvider.overrideWith((ref) => _dataset()),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('id'),
        home: Scaffold(body: CorridorInfoHeader()),
      ),
    );

void main() {
  testWidgets('kartu jaringan membuka daftar koridor, tiap baris ke detail',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Kartu "Semua" sebelumnya tidak dapat diketuk; sekarang membuka daftar.
    await tester.tap(find.text('Info Jaringan TransPadang'));
    await tester.pumpAndSettle();

    expect(find.text('Info Semua Koridor'), findsOneWidget);
    expect(find.text('Koridor K1'), findsOneWidget);
    expect(find.text('Koridor K3'), findsOneWidget);

    // Mengetuk satu koridor membuka detail halte koridor tersebut.
    await tester.tap(find.text('Koridor K3'));
    await tester.pumpAndSettle();

    expect(find.text('Info Semua Koridor'), findsNothing);
    expect(find.text('Koridor K3'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
  });

  testWidgets('swipe ke bawah menutup daftar koridor tanpa layar gelap',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final barriersBefore = find.byType(ModalBarrier).evaluate().length;

    await tester.tap(find.text('Info Jaringan TransPadang'));
    await tester.pumpAndSettle();
    expect(find.text('Info Semua Koridor'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 700));
    await tester.pumpAndSettle();

    expect(find.text('Info Semua Koridor'), findsNothing);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.byType(ModalBarrier).evaluate().length, barriersBefore);
    expect(find.text('Info Jaringan TransPadang'), findsOneWidget);
  });

  testWidgets('sheet info jaringan menampilkan tarif & metode pembayaran',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Info Jaringan TransPadang'));
    await tester.pumpAndSettle();

    // Gulir ke bagian tarif di bawah daftar koridor.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Tarif & Pembayaran'), findsOneWidget);
    for (final method in ['DEBIT', 'KREDIT', 'ATM', 'QRIS']) {
      expect(find.text(method), findsOneWidget);
    }
    expect(find.text('Rp 3.500'), findsNWidgets(2));
    expect(find.text('Rp 1.500'), findsNWidgets(2));
    expect(find.textContaining('Pembayaran berlaku 2 kali'), findsOneWidget);
  });
}
