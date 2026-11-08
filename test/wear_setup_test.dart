import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transpadang_live/core/wear_installer.dart';
import 'package:transpadang_live/features/settings/presentation/wear_setup_screen.dart';
import 'package:transpadang_live/l10n/app_localizations.dart';

Widget _app() => const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('id'),
      home: WearSetupScreen(),
    );

void main() {
  group('HostPort.parse', () {
    test('alamat valid', () {
      final hp = HostPort.parse(' 192.168.1.20:37099 ');
      expect(hp, isNotNull);
      expect(hp!.host, '192.168.1.20');
      expect(hp.port, 37099);
    });

    test('alamat tidak valid', () {
      expect(HostPort.parse(''), isNull);
      expect(HostPort.parse('192.168.1.20'), isNull);
      expect(HostPort.parse('192.168.1.20:'), isNull);
      expect(HostPort.parse(':1234'), isNull);
      expect(HostPort.parse('host:abc'), isNull);
      expect(HostPort.parse('host:70000'), isNull);
    });
  });

  testWidgets('input tidak valid menampilkan pesan, tanpa memanggil native',
      (tester) async {
    tester.view.physicalSize = const Size(400 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(WearSetupScreen.pairCodeKey), '123');
    await tester.tap(find.byKey(WearSetupScreen.installButtonKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('Periksa kembali'), findsOneWidget);
  });
}
