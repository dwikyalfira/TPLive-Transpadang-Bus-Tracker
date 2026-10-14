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
    expect(_labelOpacity(tester, 'Menyambung ulang…'), closeTo(1.0, 0.02));

    // Lewati durasi auto-hide — status abnormal harus tetap terlihat.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_labelOpacity(tester, 'Menyambung ulang…'), closeTo(1.0, 0.02));
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

  testWidgets('reconnecting → connected: keterangan ikut menyusut',
      (tester) async {
    await tester.pumpWidget(_app(ConnectionStatus.reconnecting));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_labelOpacity(tester, 'Menyambung ulang…'), closeTo(1.0, 0.02));

    // Berubah menjadi connected → label tampil lalu auto-hide.
    await tester.pumpWidget(_app(ConnectionStatus.connected));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_labelOpacity(tester, 'Terhubung'), closeTo(0.0, 0.02));
  });
}
