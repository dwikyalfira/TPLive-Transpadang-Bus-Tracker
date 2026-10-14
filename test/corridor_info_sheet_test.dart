import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/corridor_info_sheet.dart';
import 'package:transpadang_live/l10n/app_localizations.dart';

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

Bus _bus() => Bus(
      number: '57',
      lat: -0.90,
      lng: 100.30,
      corridor: 'K3',
      route: 'D - A',
      heading: 90,
      speedKmh: 20,
      lastUpdate: DateTime.now().toUtc(),
    );

Widget _app() => ProviderScope(
      overrides: [
        busesProvider.overrideWith((ref) => Stream.value([_bus()])),
        halteDatasetProvider.overrideWith((ref) => _dataset()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCorridorInfoSheet(context, 'K3'),
                child: const Text('buka info'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
      'info koridor dibuka sebagai sheet berjenjang 50%→penuh tanpa tombol tutup',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('buka info'));
    await tester.pumpAndSettle();

    // Dikonfigurasi mengikuti panduan MD3: mulai 50%, bisa ditarik ke penuh,
    // dan punya titik minimum (menarik turun menutup sheet).
    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(sheet.initialChildSize, 0.5);
    expect(sheet.maxChildSize, 1.0);
    expect(sheet.minChildSize, lessThan(0.5));

    // Isi ringkasan koridor tampil.
    expect(find.text('Koridor K3'), findsOneWidget);

    // Sesuai permintaan, tombol tutup dihilangkan dari sheet.
    expect(find.byIcon(Icons.close), findsNothing);

    // Tinggi awal sekitar setengah layar (bukan penuh).
    final height = tester.getSize(find.byType(CustomScrollView)).height;
    expect(height, greaterThan(200));
    expect(height, lessThan(400));

    // Mengetuk area luar (barrier) menutup sheet.
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsNothing);

    // Buka lagi lalu tarik ke penuh untuk memastikan catatan kemungkinan
    // perbedaan data halte tampil di bagian bawah.
    await tester.tap(find.text('buka info'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.textContaining('Data halte dapat berbeda'), findsOneWidget);
  });
}
