import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/bus_source.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';

/// Sumber bus palsu: tidak membuka jaringan, hanya aliran yang bisa disuntik.
class _FakeBusSource implements BusSource {
  final _busController = StreamController<List<Bus>>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  /// Sudah ditutup oleh provider (autoDispose).
  bool disposed = false;

  @override
  Stream<List<Bus>> get busStream => _busController.stream;

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  void connect() {}

  @override
  void dispose() {
    disposed = true;
    _busController.close();
    _statusController.close();
  }

  void emit(List<Bus> buses) => _busController.add(buses);
}

Bus _bus() => Bus(
      number: '57',
      lat: -0.9,
      lng: 100.3,
      corridor: 'K3',
      route: 'r',
      heading: 90,
      speedKmh: 20,
      lastUpdate: DateTime.now().toUtc(),
    );

void main() {
  late StreamController<bool> hours;
  late List<_FakeBusSource> sources;
  late int created;
  late int disposed;
  late ProviderContainer container;

  setUp(() {
    created = 0;
    disposed = 0;
    sources = [];
    // Single-subscription: event pertama tetap tersedia saat provider membaca.
    hours = StreamController<bool>();
    container = ProviderContainer(overrides: [
      outsideHoursProvider.overrideWith((ref) => hours.stream),
      busSourceProvider.overrideWith((ref) {
        created++;
        final source = _FakeBusSource();
        sources.add(source);
        ref.onDispose(() {
          disposed++;
          source.dispose();
        });
        return source;
      }),
    ]);
  });

  tearDown(() {
    container.dispose();
    hours.close();
  });

  test('di luar jam: tidak ada koneksi yang dibiarkan hidup', () async {
    hours.add(true);
    final buses = container.listen(busesProvider, (_, __) {});
    final status = container.listen(connectionStatusProvider, (_, __) {});
    await pumpEventQueue();

    // Bila sempat dibuat pada frame pertama, harus sudah ditutup begitu jam
    // operasional diketahui.
    expect(sources.where((s) => !s.disposed), isEmpty);
    expect(disposed, created);
    expect(status.read().valueOrNull, ConnectionStatus.outsideHours);
    expect(buses.read().valueOrNull, isEmpty);

    buses.close();
    status.close();
  });

  test('masuk jam operasional: koneksi dibuat & data mengalir', () async {
    hours.add(true);
    final buses = container.listen(busesProvider, (_, __) {});
    final status = container.listen(connectionStatusProvider, (_, __) {});
    await pumpEventQueue();
    expect(sources.where((s) => !s.disposed), isEmpty);

    // 06.00: di dalam jam operasional.
    hours.add(false);
    await pumpEventQueue();

    final active = sources.where((s) => !s.disposed).toList();
    expect(active, hasLength(1));
    active.single.emit([_bus()]);
    await pumpEventQueue();
    expect(buses.read().valueOrNull, hasLength(1));

    buses.close();
    status.close();
  });

  test('keluar jam operasional: koneksi ditutup', () async {
    hours.add(false);
    final buses = container.listen(busesProvider, (_, __) {});
    final status = container.listen(connectionStatusProvider, (_, __) {});
    await pumpEventQueue();
    expect(created, 1);

    // 19.00: di luar jam operasional.
    hours.add(true);
    await pumpEventQueue();

    expect(disposed, 1);
    expect(sources.single.disposed, isTrue);
    expect(status.read().valueOrNull, ConnectionStatus.outsideHours);
    expect(buses.read().valueOrNull, isEmpty);

    buses.close();
    status.close();
  });

  test('keluar-masuk jam operasional membuka koneksi baru', () async {
    hours.add(false);
    final buses = container.listen(busesProvider, (_, __) {});
    final status = container.listen(connectionStatusProvider, (_, __) {});
    await pumpEventQueue();

    hours.add(true);
    await pumpEventQueue();
    hours.add(false);
    await pumpEventQueue();

    expect(created, 2);
    expect(disposed, 1);
    sources.last.emit([_bus()]);
    await pumpEventQueue();
    expect(buses.read().valueOrNull, hasLength(1));

    buses.close();
    status.close();
  });
}
