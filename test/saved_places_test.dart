import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transpadang_live/features/trip/data/saved_places_store.dart';
import 'package:transpadang_live/features/trip/domain/saved_place.dart';
import 'package:transpadang_live/features/trip/domain/trip_endpoint.dart';
import 'package:transpadang_live/features/trip/presentation/trip_providers.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [savedPlacesStoreProvider.overrideWithValue(SavedPlacesStore(prefs))],
  );
  addTearDown(container.dispose);
  return container;
}

SavedPlace _place(
  String label, {
  SavedPlaceKind kind = SavedPlaceKind.halte,
  double lat = -0.9,
  double lng = 100.3,
}) =>
    SavedPlace(
      kind: kind,
      label: label,
      lat: lat,
      lng: lng,
      corridors: kind == SavedPlaceKind.halte ? 'K3' : null,
    );

void main() {
  test('toggleFavorite menambah lalu menghapus', () async {
    final container = await _container();
    final notifier = container.read(savedPlacesProvider.notifier);
    expect(container.read(savedPlacesProvider).favorites, isEmpty);

    await notifier.toggleFavorite(_place('A'));
    expect(
      container.read(savedPlacesProvider).favorites.map((p) => p.label),
      ['A'],
    );

    await notifier.toggleFavorite(_place('A'));
    expect(container.read(savedPlacesProvider).favorites, isEmpty);
  });

  test('favorit bertahan setelah container dibangun ulang', () async {
    final container = await _container();
    await container
        .read(savedPlacesProvider.notifier)
        .toggleFavorite(_place('Masjid'));

    final prefs = await SharedPreferences.getInstance();
    final reloaded = ProviderContainer(
      overrides: [
        savedPlacesStoreProvider.overrideWithValue(SavedPlacesStore(prefs)),
      ],
    );
    addTearDown(reloaded.dispose);

    expect(reloaded.read(savedPlacesProvider).favorites.single.label, 'Masjid');
  });

  test('addRecent unik & dibatasi maxRecents', () async {
    final container = await _container();
    final notifier = container.read(savedPlacesProvider.notifier);
    for (var i = 0; i < 10; i++) {
      await notifier.addRecent(_place('T$i', lat: -0.9 + i * 0.01));
    }

    final recents = container.read(savedPlacesProvider).recents;
    expect(recents.length, SavedPlacesNotifier.maxRecents);
    expect(recents.first.label, 'T9');

    // Menambah ulang memindahkan ke depan tanpa duplikat.
    await notifier.addRecent(_place('T5', lat: -0.9 + 5 * 0.01));
    final after = container.read(savedPlacesProvider).recents;
    expect(after.length, SavedPlacesNotifier.maxRecents);
    expect(after.first.label, 'T5');
    expect(after.where((p) => p.label == 'T5').length, 1);
  });

  test('SavedPlace.fromEndpoint mengabaikan lokasi GPS', () {
    expect(SavedPlace.fromEndpoint(const TripEndpoint.gps()), isNull);

    final saved = SavedPlace.fromEndpoint(
      TripEndpoint.place(label: 'X', position: const LatLng(-0.9, 100.3)),
    );
    expect(saved, isNotNull);
    expect(saved!.kind, SavedPlaceKind.place);
    expect(saved.toEndpoint().label, 'X');
  });
}
