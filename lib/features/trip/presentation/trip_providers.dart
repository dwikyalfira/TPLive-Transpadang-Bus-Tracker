import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../tracking/data/bus_model.dart';
import '../../tracking/domain/geo_utils.dart' as geo;
import '../../tracking/domain/halte_tracker.dart';
import '../../tracking/presentation/providers.dart';
import '../data/geocoding_service.dart';
import '../domain/trip_endpoint.dart';
import '../domain/trip_planner.dart';

/// Bus yang mendekati halte naik pada leg pertama sebuah rute.
class TripBus {
  final Bus bus;
  final double distanceKm;
  final int? etaMinutes;

  /// Progres halte bus ini (dipakai untuk membuka detail & fitur ikuti).
  final HalteProgress progress;

  const TripBus({
    required this.bus,
    required this.distanceKm,
    required this.etaMinutes,
    required this.progress,
  });
}

/// Klien geocoding (singleton selama app hidup).
final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  final service = GeocodingService();
  ref.onDispose(service.close);
  return service;
});

/// Titik asal perjalanan (default: lokasi GPS pengguna).
final tripOriginEndpointProvider =
    StateProvider<TripEndpoint>((ref) => const TripEndpoint.gps());

/// Titik tujuan perjalanan (null = belum dipilih).
final tripDestinationEndpointProvider =
    StateProvider<TripEndpoint?>((ref) => null);

/// Semua halte unik dari seluruh koridor (untuk pemilih halte).
final halteEntriesProvider = Provider<List<HalteEntry>>((ref) {
  final dataset = ref.watch(halteDatasetProvider).valueOrNull;
  if (dataset == null) return const [];

  final byName = <String, HalteEntry>{};
  for (final stops in dataset.corridors.values) {
    for (final dir in stops.arah.values) {
      for (final halte in dir.halte) {
        final key = halte.nama.toLowerCase();
        final existing = byName[key];
        if (existing == null) {
          byName[key] = HalteEntry(halte: halte, corridors: {stops.kode});
        } else {
          existing.corridors.add(stops.kode);
        }
      }
    }
  }

  final list = byName.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
});

/// Jarak lokasi pengguna ke koridor (jarak terpendek ke halte koridor).
/// Dipakai untuk mengurutkan daftar halte tujuan: koridor terdekat lebih dulu.
final corridorProximityProvider = Provider<Map<String, double>>((ref) {
  final user = ref.watch(userLocationProvider).valueOrNull;
  final dataset = ref.watch(halteDatasetProvider).valueOrNull;
  final map = <String, double>{};
  if (user == null || dataset == null) return map;

  for (final stops in dataset.corridors.values) {
    var best = double.infinity;
    for (final dir in stops.arah.values) {
      for (final halte in dir.halte) {
        final d = geo.distanceKm(user, halte.pos);
        if (d < best) best = d;
      }
    }
    map[stops.kode] = best;
  }
  return map;
});

/// Teks pencarian tempat (tab "Tempat" pada pemilih).
final destinationQueryProvider = StateProvider<String>((ref) => '');

/// Hasil pencarian tempat dari [destinationQueryProvider].
final destinationResultsProvider =
    FutureProvider<List<GeocodingResult>>((ref) async {
  final query = ref.watch(destinationQueryProvider);
  if (query.trim().length < 3) return const [];
  return ref.watch(geocodingServiceProvider).search(query);
});

/// Rute menuju tujuan terpilih (null bila data belum siap).
final tripPlanProvider = Provider<TripPlan?>((ref) {
  final originEndpoint = ref.watch(tripOriginEndpointProvider);
  final destination = ref.watch(tripDestinationEndpointProvider);
  if (destination == null) return null;

  final LatLng? origin = originEndpoint.isGps
      ? ref.watch(userLocationProvider).valueOrNull
      : originEndpoint.position;
  if (origin == null) return null;

  final dataset = ref.watch(halteDatasetProvider).valueOrNull;
  if (dataset == null) return null;

  return TripPlanner.plan(
    dataset,
    origin,
    destination.position!,
    destinationLabel: destination.label,
    originName: originEndpoint.kind == EndpointKind.halte
        ? originEndpoint.label
        : null,
    destinationName: destination.kind == EndpointKind.halte
        ? destination.label
        : null,
  );
});

/// Bus terdekat menuju halte naik pada [leg] (diurutkan menurut ETA).
final tripBusesProvider = Provider.family<List<TripBus>, TripLeg>((ref, leg) {
  final buses = ref.watch(busesProvider).valueOrNull ?? const <Bus>[];
  final dataset = ref.watch(halteDatasetProvider).valueOrNull;
  final headingTracker = ref.watch(headingTrackerProvider);
  if (dataset == null) return const [];

  final nowUtc = DateTime.now().toUtc();
  final result = <TripBus>[];
  for (final bus in buses) {
    if (bus.isStale(nowUtc)) continue;
    if (bus.corridor != leg.corridor) continue;

    final estimated = headingTracker.update(bus, nowUtc);
    final progress = HalteTracker.track(
      bus,
      dataset,
      estimatedHeading: estimated,
    );
    if (progress == null || progress.arahKey != leg.arahKey) continue;
    // Halte naik harus masih di depan bus (belum terlewati).
    if (leg.boardIndex < progress.nextIndex) continue;

    final km = geo.distanceKm(bus.position, leg.board.pos);
    result.add(TripBus(
      bus: bus,
      distanceKm: km,
      etaMinutes: geo.estimateEtaMinutes(km, bus.speedKmh),
      progress: progress,
    ));
  }

  result.sort((a, b) {
    final ea = a.etaMinutes ?? 1 << 30;
    final eb = b.etaMinutes ?? 1 << 30;
    return ea.compareTo(eb);
  });
  return result;
});
