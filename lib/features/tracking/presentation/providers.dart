import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config.dart';
import '../data/bus_model.dart';
import '../data/bus_source.dart';
import '../data/halte_data.dart';
import '../data/trans_ws_datasource.dart';
import '../domain/bus_with_distance.dart';
import '../domain/corridor_info.dart';
import '../domain/halte_tracker.dart';
import '../domain/heading_tracker.dart';

/// Exception ramah untuk masalah lokasi.
class LocationException implements Exception {
  final String message;
  const LocationException(this.message);
  @override
  String toString() => message;
}

/// Dataset halte per koridor (dimuat sekali dari aset).
final halteDatasetProvider = FutureProvider<HalteDataset>((ref) {
  return loadHalteDataset();
});

/// Pelacak arah gerak bus dari riwayat posisi (singleton selama app hidup).
final headingTrackerProvider = Provider<HeadingTracker>((ref) {
  return HeadingTracker();
});

/// Sumber data bus: WebSocket asli.
final busSourceProvider = Provider<BusSource>((ref) {
  final BusSource source = TransWsDataSource();
  source.connect();
  ref.onDispose(source.dispose);
  return source;
});

/// Aliran daftar bus terbaru.
final busesProvider = StreamProvider<List<Bus>>((ref) {
  return ref.watch(busSourceProvider).busStream;
});

/// Aliran status koneksi.
final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  return ref.watch(busSourceProvider).statusStream;
});

/// Benar bila saat ini di luar jam operasional TransPadang (WIB).
///
/// Jam operasional didefinisikan pada [AppConfig]. Nilai dihitung ulang tiap
/// menit agar penanda status ikut berubah begitu jam berganti tanpa perlu
/// membuka ulang aplikasi.
final outsideHoursProvider = StreamProvider<bool>((ref) async* {
  bool compute() => AppConfig.isOutsideOperationalHours(DateTime.now());
  yield compute();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => compute());
});

/// Koridor tab yang sedang dipilih di layar utama (null = tab "Semua").
///
/// Nilai ini hanya status UI: penyaringan bus per tab dilakukan di daftar,
/// sehingga halaman tetap menampilkan data koridornya masing-masing saat
/// pengguna menggeser antar tab.
final selectedCorridorProvider = StateProvider<String?>((ref) => null);

/// Bus yang sedang diikuti via notifikasi foreground service.
/// Nilai berupa kunci `'<koridor>|<nomorBus>'` (null = tidak mengikuti).
final followedBusProvider = StateProvider<String?>((ref) => null);

/// Apakah bottom sheet detail bus sedang terbuka. Saat bernilai true, kartu
/// bus melayang ditampilkan dalam versi mini (tidak ikut memelar).
final pinnedDetailOpenProvider = StateProvider<bool>((ref) => false);

/// Apakah kartu bus di-pin tampil dalam versi mini (hanya garis progres +
/// label asal/tujuan).
///
/// Kartu beristirahat dalam ukuran mini secara default; melar hanya ketika
/// pengguna menyengajanya (mengetuk kartu). Guliran layar atau berpindah
/// halaman selalu mengembalikan kartu ke mini.
final pinnedCardCollapsedProvider = StateProvider<bool>((ref) => true);

/// Kunci bus (untuk [followedBusProvider]).
String busFollowKey(String corridor, String busNumber) =>
    '$corridor|$busNumber';

/// Lokasi pengguna (GPS). Menangani permintaan izin terlebih dahulu.
final userLocationProvider = StreamProvider<LatLng>((ref) async* {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw const LocationException(
      'Layanan lokasi (GPS) nonaktif. Aktifkan lokasi untuk melanjutkan.',
    );
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    throw const LocationException('Izin lokasi ditolak.');
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationException(
      'Izin lokasi ditolak permanen. Aktifkan dari Pengaturan aplikasi.',
    );
  }

  final stream = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  ).map((p) => LatLng(p.latitude, p.longitude));

  yield* stream;
});

/// Daftar koridor yang tersedia, diambil dari data bus yang masuk.
final availableCorridorsProvider = Provider<List<String>>((ref) {
  final buses = ref.watch(busesProvider).valueOrNull ?? const <Bus>[];
  final corridors = <String>{
    for (final bus in buses)
      if (bus.corridor.isNotEmpty) bus.corridor,
  };
  final sorted = corridors.toList()..sort();
  return sorted;
});

/// Daftar bus terdekat: terurut berdasarkan jarak.
///
/// Sengaja **tidak** difilter koridor — setiap tab baru memfilter sendiri
/// supaya isi halaman tetap milik koridor masing-masing saat tab digeser.
final nearbyBusesProvider = Provider<List<BusWithDistance>>((ref) {
  final buses = ref.watch(busesProvider).valueOrNull ?? const <Bus>[];
  final location = ref.watch(userLocationProvider).valueOrNull;
  final dataset = ref.watch(halteDatasetProvider).valueOrNull;
  final headingTracker = ref.watch(headingTrackerProvider);
  if (location == null) return const [];

  final nowUtc = DateTime.now().toUtc();

  final result = <BusWithDistance>[];
  for (final bus in buses) {
    if (bus.isStale(nowUtc)) continue;

    final estimated = headingTracker.update(bus, nowUtc);
    String? directionKey;
    String? destinationLabel;
    if (dataset != null) {
      final progress = HalteTracker.track(
        bus,
        dataset,
        estimatedHeading: estimated,
      );
      if (progress != null) {
        directionKey = progress.arahKey;
        destinationLabel = progress.destinationLabel;
      }
    }

    result.add(BusWithDistance.compute(
      bus,
      location,
      directionKey: directionKey,
      destinationLabel: destinationLabel,
      resolvedHeading: estimated ?? bus.heading,
    ));
  }

  result.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return result;
});

/// Ringkasan info seluruh jaringan TransPadang untuk tab "Semua": jumlah bus
/// aktif, jumlah koridor, serta jumlah halte (total & unik) pada dataset.
final networkInfoProvider = Provider<NetworkInfo>((ref) {
  final buses = ref.watch(busesProvider).valueOrNull ?? const <Bus>[];
  final dataset = ref.watch(halteDatasetProvider).valueOrNull;
  final nowUtc = DateTime.now().toUtc();

  final activeBuses = buses.where((bus) => !bus.isStale(nowUtc)).length;

  final corridors = <String>{
    ...?dataset?.corridors.keys,
    for (final bus in buses)
      if (bus.corridor.isNotEmpty) bus.corridor.toUpperCase(),
  };

  var totalStops = 0;
  final unique = <String>{};
  final allStops = dataset?.corridors.values ?? const <CorridorStops>[];
  for (final stops in allStops) {
    for (final direction in stops.arah.values) {
      totalStops += direction.halte.length;
      for (final halte in direction.halte) {
        final name = halte.nama.trim().toLowerCase();
        if (name.isNotEmpty) unique.add(name);
      }
    }
  }

  return NetworkInfo(
    activeBuses: activeBuses,
    corridorCount: corridors.length,
    totalStops: totalStops,
    uniqueStops: unique.length,
  );
});

/// Ringkasan info per koridor (kunci = kode koridor huruf besar, mis. `K3`).
///
/// Menggabungkan jumlah bus aktif terkini (dari WebSocket, bus kedaluwarsa
/// diabaikan) dengan jumlah halte & terminus dari dataset statis. Dipakai oleh
/// [CorridorInfoHeader] dan bottom sheet detail koridor.
final corridorInfoProvider = Provider<Map<String, CorridorInfo>>((ref) {
  final buses = ref.watch(busesProvider).valueOrNull ?? const <Bus>[];
  final dataset = ref.watch(halteDatasetProvider).valueOrNull;
  final nowUtc = DateTime.now().toUtc();

  final activeByCorridor = <String, int>{};
  final routeByCorridor = <String, String>{};
  for (final bus in buses) {
    if (bus.corridor.isEmpty || bus.isStale(nowUtc)) continue;
    final code = bus.corridor.toUpperCase();
    activeByCorridor[code] = (activeByCorridor[code] ?? 0) + 1;
    if (bus.route.isNotEmpty) {
      routeByCorridor.putIfAbsent(code, () => bus.route);
    }
  }

  final codes = <String>{
    ...?dataset?.corridors.keys,
    ...activeByCorridor.keys,
  };

  final result = <String, CorridorInfo>{};
  for (final code in codes) {
    result[code] = CorridorInfo.of(
      code,
      dataset?.forCorridor(code),
      activeByCorridor[code] ?? 0,
      routeName: routeByCorridor[code],
    );
  }
  return result;
});
