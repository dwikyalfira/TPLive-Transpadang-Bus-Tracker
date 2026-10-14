import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';
import 'package:transpadang_live/features/trip/presentation/location_picker_screen.dart';
import 'package:transpadang_live/l10n/app_localizations.dart';

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
  });
  return HalteDataset({'K3': k3});
}

Widget _app({required bool includeGps}) {
  return ProviderScope(
    overrides: [
      halteDatasetProvider.overrideWith((ref) => _dataset()),
      userLocationProvider.overrideWith(
        (ref) => Stream.value(const LatLng(-0.90, 100.30)),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('id'),
      home: LocationPickerScreen(title: 'Pilih asal', includeGps: includeGps),
    ),
  );
}

void main() {
  testWidgets('pemilih asal menampilkan Lokasi saya + halte terdekat',
      (tester) async {
    await tester.pumpWidget(_app(includeGps: true));
    await tester.pumpAndSettle();

    expect(find.text('Lokasi saya'), findsOneWidget);
    expect(find.text('HALTE TERDEKAT DARI LOKASI ANDA'), findsOneWidget);
    expect(find.text('SEMUA HALTE'), findsOneWidget);

    // Halte terdekat berada paling atas (A tepat di lokasi pengguna).
    expect(find.text('A'), findsWidgets);
    expect(find.text('0 m'), findsOneWidget);
  });

  testWidgets('pemilih tujuan tidak menampilkan opsi Lokasi saya',
      (tester) async {
    await tester.pumpWidget(_app(includeGps: false));
    await tester.pumpAndSettle();

    expect(find.text('Lokasi saya'), findsNothing);
    expect(find.text('Cari halte…'), findsOneWidget);
  });
}
