import 'package:flutter_test/flutter_test.dart';
import 'package:transpadang_live/features/tracking/data/trans_ws_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('status awal selalu connecting (tanpa cek jam operasional) & auto-reconnect',
      () async {
    final source = TransWsDataSource(url: 'ws://invalid.test/socket');
    final statuses = <ConnectionStatus>[];
    final sub = source.statusStream.listen(statuses.add);

    // Host palsu: socket akan gagal, tapi datasource tetap mencari koneksi
    // (tidak lagi ada batasan jam operasional). Status pertama selalu connecting.
    source.connect();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(statuses, isNotEmpty);
    expect(statuses.first, ConnectionStatus.connecting);

    // Koneksi tetap dicoba setelah kegagalan (auto-reconnect berjalan).
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(source, isA<TransWsDataSource>());

    await sub.cancel();
    source.dispose();
  });
}
