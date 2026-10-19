import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/features/tracking/data/corridor_route.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/presentation/providers.dart';

Halte _h(String nama, double lat, double lng) =>
    Halte(nama: nama, pos: LatLng(lat, lng));

HalteDataset _dataset() => HalteDataset({
      'K1': CorridorStops(kode: 'K1', arah: {
        'pergi': CorridorDirection(label: 'A - B', halte: [
          _h('A', -0.90, 100.30),
          _h('B', -0.91, 100.31),
        ]),
      }),
      'K3': CorridorStops(kode: 'K3', arah: {
        'pergi': CorridorDirection(label: 'C - D', halte: [
          _h('C', -0.92, 100.32),
          _h('D', -0.93, 100.33),
        ]),
        'pulang': CorridorDirection(label: 'D - C', halte: [
          _h('D', -0.93, 100.33),
          _h('C', -0.92, 100.32),
        ]),
      }),
    });

ProviderContainer _container() {
  final container = ProviderContainer(overrides: [
    halteDatasetProvider.overrideWith((ref) => _dataset()),
    corridorRouteDatasetProvider
        .overrideWith((ref) async => const CorridorRouteDataset({})),
    manualCorridorRouteProvider
        .overrideWith((ref) async => const CorridorRouteDataset({})),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('tab "Semua" menggambar jalur seluruh koridor', () {
    final container = _container();

    final paths = container.read(corridorPathsProvider);

    expect(paths.map((p) => p.corridor).toSet(), {'K1', 'K3'});
    expect(paths, hasLength(3)); // K1/pergi + K3/pergi + K3/pulang
  });

  test('koridor terpilih di peta hanya menggambar jalur koridor itu', () {
    final container = _container();
    container.read(mapCorridorProvider.notifier).state = 'K3';

    final paths = container.read(corridorPathsProvider);

    expect(paths.map((p) => p.corridor).toSet(), {'K3'});
    expect(paths.map((p) => p.directionKey).toSet(), {'pergi', 'pulang'});
    expect(paths, hasLength(2));
  });

  test('tab beranda tidak menyaring jalur peta', () {
    final container = _container();
    // Memilih tab koridor di beranda tidak mengubah filter peta.
    container.read(selectedCorridorProvider.notifier).state = 'K3';

    final paths = container.read(corridorPathsProvider);

    expect(paths.map((p) => p.corridor).toSet(), {'K1', 'K3'});
  });
}
