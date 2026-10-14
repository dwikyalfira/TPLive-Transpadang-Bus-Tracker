import 'package:flutter_test/flutter_test.dart';
import 'package:transpadang_live/features/tracking/data/bus_model.dart';
import 'package:transpadang_live/features/tracking/data/demo_bus_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DemoBusSource membangkitkan bus bergerak di koridor nyata', () async {
    final source = DemoBusSource(tick: const Duration(milliseconds: 15));
    addTearDown(source.dispose);

    final emissions = <List<Bus>>[];
    final sub = source.busStream.listen(emissions.add);
    source.connect();

    await Future<void>.delayed(const Duration(milliseconds: 120));
    await sub.cancel();

    expect(emissions, isNotEmpty, reason: 'harus ada emission bus');
    final first = emissions.first;
    expect(first, isNotEmpty);

    const corridors = {'K1', 'K2', 'K3', 'K4', 'K5', 'K6'};
    for (final bus in first) {
      expect(corridors, contains(bus.corridor));
      expect(bus.number, isNotEmpty);
      expect(bus.lastUpdate, isNotNull);
      expect(bus.position.latitude, isNot(0));
    }

    // Bus harus bergeser antar emission.
    if (emissions.length >= 2) {
      final a = emissions.first.first;
      final b = emissions[1].first;
      final moved = a.lat != b.lat || a.lng != b.lng;
      expect(moved, isTrue, reason: 'posisi bus harus berubah');
    }
  });

  test('DemoBusSource melaporkan status connected', () async {
    final source = DemoBusSource(tick: const Duration(milliseconds: 15));
    addTearDown(source.dispose);

    final statuses = <dynamic>[];
    final sub = source.statusStream.listen(statuses.add);
    source.connect();

    await Future<void>.delayed(const Duration(milliseconds: 80));
    await sub.cancel();

    expect(statuses, isNotEmpty);
    expect(statuses.last.toString(), contains('connected'));
  });
}
