import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/bus_source.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';

/// Sumber bus tanpa jaringan/timer (mencatat apakah `connect()` dipanggil).
class _SilentBusSource implements BusSource {
  bool connected = false;

  @override
  Stream<List<Bus>> get busStream => const Stream<List<Bus>>.empty();

  @override
  Stream<ConnectionStatus> get statusStream =>
      const Stream<ConnectionStatus>.empty();

  @override
  void connect() => connected = true;

  @override
  void dispose() {}
}

ProviderContainer _container({bool outsideHours = false}) {
  final container = ProviderContainer(
    overrides: [
      // Timer menit-an dihindari agar pengujian tidak meninggalkan timer aktif.
      outsideHoursProvider.overrideWith((ref) => Stream.value(outsideHours)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('pembaruan live aktif saat aplikasi di depan', () {
    final container = _container();
    expect(container.read(liveUpdatesAllowedProvider), isTrue);
  });

  test('socket ditutup saat aplikasi di latar belakang', () {
    final container = _container();
    container.read(appPausedProvider.notifier).state = true;
    expect(container.read(liveUpdatesAllowedProvider), isFalse);
  });

  test('socket tetap hidup saat mengikuti bus walau di latar belakang', () {
    final container = _container();
    container.read(appPausedProvider.notifier).state = true;
    container.read(followedBusProvider.notifier).state = 'K3|11';
    expect(container.read(liveUpdatesAllowedProvider), isTrue);
  });

  test('di luar jam operasional socket tidak dibuka', () async {
    final container = _container(outsideHours: true);
    // Tunggu emisi pertama status jam operasional (sebelumnya dianggap
    // "di dalam jam" selama satu mikrotask).
    await container.read(outsideHoursProvider.future);
    expect(container.read(liveUpdatesAllowedProvider), isFalse);
  });

  test('daftar bus kosong & sumber tidak disentuh saat aplikasi di belakang',
      () async {
    final source = _SilentBusSource();
    final container = ProviderContainer(
      overrides: [
        outsideHoursProvider.overrideWith((ref) => Stream.value(false)),
        busSourceProvider.overrideWithValue(source),
      ],
    );
    addTearDown(container.dispose);

    container.read(appPausedProvider.notifier).state = true;
    expect(await container.read(busesProvider.future), isEmpty);
    expect(source.connected, isFalse);
  });

  test('status koneksi netral (menghubungkan) saat aplikasi di belakang',
      () async {
    final container = ProviderContainer(
      overrides: [
        outsideHoursProvider.overrideWith((ref) => Stream.value(false)),
        busSourceProvider.overrideWithValue(_SilentBusSource()),
      ],
    );
    addTearDown(container.dispose);

    container.read(appPausedProvider.notifier).state = true;
    expect(
      await container.read(connectionStatusProvider.future),
      ConnectionStatus.connecting,
    );
  });
}
