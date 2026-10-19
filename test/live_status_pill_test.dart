import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transpadang_live/features/tracking/data/trans_ws_datasource.dart';
import 'package:transpadang_live/features/tracking/presentation/widgets/live_status_pill.dart';
import 'package:transpadang_live/l10n/app_localizations.dart';

Widget _app(ConnectionStatus? status) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('id'),
      home: Scaffold(body: LiveStatusPill(status: status)),
    );

/// Opasitas label (0 = tersembunyi, 1 = tampil penuh) — label dibungkus
/// [Opacity] di dalam pill.
double _labelOpacity(WidgetTester tester, String label) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(label), matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  testWidgets('reconnecting: keterangan tetap tampil (tidak auto-hide)',
      (tester) async {
    await tester.pumpWidget(_app(ConnectionStatus.reconnecting));
    await tester.pumpAndSettle();
    expect(_labelOpacity(tester, 'Menyambung ulang'), closeTo(1.0, 0.02));

    // Lewati durasi auto-hide — status abnormal harus tetap terlihat.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_labelOpacity(tester, 'Menyambung ulang'), closeTo(1.0, 0.02));
  });

  testWidgets('connecting: keterangan tetap tampil (tidak auto-hide)',
      (tester) async {
    await tester.pumpWidget(_app(ConnectionStatus.connecting));
    await tester.pumpAndSettle();
    expect(_labelOpacity(tester, 'Menyambung'), closeTo(1.0, 0.02));

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_labelOpacity(tester, 'Menyambung'), closeTo(1.0, 0.02));
  });

  testWidgets('disconnected: keterangan tetap tampil (tidak auto-hide)',
      (tester) async {
    await tester.pumpWidget(_app(ConnectionStatus.disconnected));
    await tester.pumpAndSettle();
    expect(_labelOpacity(tester, 'Tidak terhubung'), closeTo(1.0, 0.02));

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_labelOpacity(tester, 'Tidak terhubung'), closeTo(1.0, 0.02));
  });

  testWidgets('connected: keterangan auto-hide setelah beberapa saat',
      (tester) async {
    await tester.pumpWidget(_app(ConnectionStatus.connected));
    await tester.pumpAndSettle();
    expect(_labelOpacity(tester, 'Terhubung'), closeTo(1.0, 0.02));

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_labelOpacity(tester, 'Terhubung'), closeTo(0.0, 0.02));
  });

  testWidgets('label menyusut (tanpa overflow) saat ruang sempit',
      (tester) async {
    for (final status in ConnectionStatus.values) {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 96,
              child: LiveStatusPill(status: status),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('reconnecting → connected: keterangan ikut menyusut',
      (tester) async {
    await tester.pumpWidget(_app(ConnectionStatus.reconnecting));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_labelOpacity(tester, 'Menyambung ulang'), closeTo(1.0, 0.02));

    // Berubah menjadi connected → label tampil lalu auto-hide.
    await tester.pumpWidget(_app(ConnectionStatus.connected));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_labelOpacity(tester, 'Terhubung'), closeTo(0.0, 0.02));
  });

  testWidgets('label "…" memakai titik animasi saja, bukan elipsis bawaan',
      (tester) async {
    await tester.pumpWidget(_app(ConnectionStatus.connecting));
    await tester.pumpAndSettle();

    // Teks dasar dipotong tanpa menggambar "…" milik Flutter sendiri.
    final base = tester.widget<Text>(find.text('Menyambung'));
    expect(base.overflow, TextOverflow.clip);
    expect(find.text('…'), findsNothing);

    // Hanya tiga titik dari animasi (bukan elipsis + tiga titik).
    expect(find.text('.'), findsNWidgets(3));
  });

  testWidgets('ruang sempit: teks dipotong, titik animasi tetap tiga & utuh',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('id'),
      home: Scaffold(
        body: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 96,
            child: LiveStatusPill(status: ConnectionStatus.reconnecting),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('…'), findsNothing);
    expect(find.text('.'), findsNWidgets(3));
    // Pill tidak pernah melebihi ruang yang tersedia.
    expect(
      tester.getSize(find.byType(LiveStatusPill)).width,
      lessThanOrEqualTo(96),
    );
  });
}
