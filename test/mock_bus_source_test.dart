import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/core/config.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/bus_source.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/data/mock_bus_source.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';

Halte _h(double lat, double lng, String nama) =>
    Halte(nama: nama, pos: LatLng(lat, lng));

/// Dua koridor, masing-masing dua arah dengan tiga halte.
HalteDataset _dataset() {
  final k1 = CorridorStops(kode: 'K1', arah: {
    'pergi': CorridorDirection(label: 'A - B', halte: [
      _h(-0.900, 100.300, 'A'),
      _h(-0.905, 100.305, 'B'),
      _h(-0.910, 100.310, 'C'),
    ]),
    'pulang': CorridorDirection(label: 'C - A', halte: [
      _h(-0.910, 100.310, 'C'),
      _h(-0.905, 100.305, 'B'),
      _h(-0.900, 100.300, 'A'),
    ]),
  });
  final k3 = CorridorStops(kode: 'K3', arah: {
    'pergi': CorridorDirection(label: 'D - E', halte: [
      _h(-0.920, 100.320, 'D'),
      _h(-0.925, 100.325, 'E'),
    ]),
  });
  return HalteDataset({'K1': k1, 'K3': k3});
}

void main() {
  test('menghasilkan bus untuk tiap koridor & arah, dengan data segar',
      () async {
    final source = MockBusSource(
      dataset: _dataset(),
      tick: const Duration(milliseconds: 20),
      busesPerDirection: 2,
    );
    addTearDown(source.dispose);

    final statuses = <ConnectionStatus>[];
    final subStatus = source.statusStream.listen(statuses.add);
    addTearDown(subStatus.cancel);

    final frames = <List<Bus>>[];
    final subBus = source.busStream.listen(frames.add);
    addTearDown(subBus.cancel);

    source.connect();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(statuses, contains(ConnectionStatus.connected));
    expect(frames, isNotEmpty);

    final buses = frames.first;
    // K1 pergi + K1 pulang + K3 pergi = 3 arah × 2 bus.
    expect(buses, hasLength(6));
    expect(buses.map((b) => b.corridor).toSet(), {'K1', 'K3'});
    expect(buses.map((b) => b.route).toSet(), {'A - B', 'C - A', 'D - E'});

    final nowUtc = DateTime.now().toUtc();
    for (final bus in buses) {
      expect(bus.lastUpdate, isNotNull);
      // Tidak boleh langsung dianggap basi (>5 menit) oleh UI.
      expect(bus.isStale(nowUtc), isFalse);
      expect(bus.speedKmh, greaterThan(0));
      expect(bus.heading, isNotNull);
      expect(bus.number, isNotEmpty);
    }
  });

  test('bus bergerak di antara pembaruan', () async {
    final source = MockBusSource(
      dataset: _dataset(),
      tick: const Duration(milliseconds: 20),
      busesPerDirection: 1,
    );
    addTearDown(source.dispose);

    final frames = <List<Bus>>[];
    final sub = source.busStream.listen(frames.add);
    addTearDown(sub.cancel);

    source.connect();
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(frames.length, greaterThan(1));
    final first = frames.first.first;
    final last = frames.last.first;
    expect(
      (last.lat - first.lat).abs() + (last.lng - first.lng).abs(),
      greaterThan(0),
      reason: 'posisi bus harus berubah antar pembaruan',
    );
  });

  test('dataset kosong tidak membuat aliran macet', () async {
    final source = MockBusSource(
      dataset: const HalteDataset({}),
      tick: const Duration(milliseconds: 20),
    );
    addTearDown(source.dispose);

    final frames = <List<Bus>>[];
    final sub = source.busStream.listen(frames.add);
    addTearDown(sub.cancel);

    source.connect();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(frames, isNotEmpty);
    expect(frames.first, isEmpty);
  });

  group('sakelar mode demo di provider', () {
    test('mockBusEnabledProvider memilih sumber tiruan', () {
      final container = ProviderContainer(
        overrides: [mockBusEnabledProvider.overrideWithValue(true)],
      );
      addTearDown(container.dispose);
      expect(container.read(busSourceProvider), isA<MockBusSource>());
    });

    test('build biasa tidak menyalakan data tiruan', () {
      // `flutter test`/build tanpa --dart-define=MOCK_BUS harus tetap memakai
      // data asli; ini yang menjaga mode demo tidak bocor ke rilis.
      expect(AppConfig.useMockBus, isFalse);
      expect(AppConfig.mockLocationRaw, isEmpty);
    });

    test('mode demo mengabaikan jam operasional', () async {
      final container = ProviderContainer(
        overrides: [
          mockBusEnabledProvider.overrideWithValue(true),
          outsideHoursProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(outsideHoursProvider.future);
      expect(container.read(isOutsideHoursProvider), isFalse);
    });

    test('di luar mode demo jam operasional tetap dihormati', () async {
      final container = ProviderContainer(
        overrides: [
          mockBusEnabledProvider.overrideWithValue(false),
          outsideHoursProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(outsideHoursProvider.future);
      expect(container.read(isOutsideHoursProvider), isTrue);
    });

    test('MOCK_LOCATION dipakai sebagai lokasi pengguna', () async {
      final container = ProviderContainer(
        overrides: [
          mockLocationProvider.overrideWithValue(const LatLng(-0.9, 100.35)),
        ],
      );
      addTearDown(container.dispose);

      final location = await container.read(userLocationProvider.future);
      expect(location.latitude, -0.9);
      expect(location.longitude, 100.35);
    });
  });
}
