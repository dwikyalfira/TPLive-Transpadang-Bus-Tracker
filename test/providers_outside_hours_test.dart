import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/bus_source.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';

/// Sumber bus palsu: aliran broadcast yang bisa disuntikkan data.
class _FakeBusSource implements BusSource {
  final _busController = StreamController<List<Bus>>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  @override
  Stream<List<Bus>> get busStream => _busController.stream;

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  void connect() {}

  @override
  void dispose() {
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

ProviderContainer _container(bool outside, _FakeBusSource fake) {
  final container = ProviderContainer(overrides: [
    busSourceProvider.overrideWithValue(fake),
    outsideHoursProvider.overrideWith((ref) => Stream.value(outside)),
  ]);
  addTearDown(container.dispose);
  addTearDown(fake.dispose);
  return container;
}

void main() {
  test('busesProvider kosong di luar jam operasional walau data tetap masuk',
      () async {
    final fake = _FakeBusSource();
    final container = _container(true, fake);
    final sub = container.listen(busesProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);

    // Server tetap mengirim posisi bus, tetapi tidak diteruskan ke UI.
    fake.emit([_bus()]);
    await Future<void>.delayed(Duration.zero);

    expect(sub.read().valueOrNull, isEmpty);
  });

  test('busesProvider meneruskan data di dalam jam operasional', () async {
    final fake = _FakeBusSource();
    final container = _container(false, fake);
    final sub = container.listen(busesProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);

    fake.emit([_bus()]);
    await Future<void>.delayed(Duration.zero);

    expect(sub.read().valueOrNull, hasLength(1));
  });
}
