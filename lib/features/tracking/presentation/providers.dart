import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config.dart';
import '../data/bus_model.dart';
import '../data/bus_source.dart';
import '../data/corridor_route.dart';
import '../data/halte_data.dart';
import '../data/trans_ws_datasource.dart';
import '../domain/bus_with_distance.dart';
import '../domain/corridor_info.dart';
import '../domain/corridor_path.dart';
import '../domain/halte_tracker.dart';
import '../domain/heading_tracker.dart';
import '../domain/map_marker.dart';
import '../domain/map_stop.dart';

/// Jenis kegagalan lokasi, dipetakan ke teks oleh lapisan UI agar pesan
/// mengikuti bahasa aplikasi (bukan hardcoded di provider).
enum LocationErrorKind {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

/// Exception ramah untuk masalah lokasi.
class LocationException implements Exception {
  final LocationErrorKind kind;
  const LocationException(this.kind);
  @override
  String toString() => kind.name;
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
///
/// `autoDispose` bukan tanpa alasan: di luar jam operasional tidak ada
/// konsumen ([busesProvider] & [connectionStatusProvider] berhenti membacanya),
/// sehingga socket ditutup alih-alih menganggur sepanjang malam. Begitu jam
/// operasional kembali, provider dihitung ulang dan koneksi dibuka lagi.
final busSourceProvider = Provider.autoDispose<BusSource>((ref) {
  final BusSource source = TransWsDataSource();
  source.connect();
  ref.onDispose(source.dispose);
  return source;
});

/// Benar bila saat ini di luar jam operasional TransPadang (boolean). Memakai
/// `select` agar konsumen hanya dihitung ulang saat nilainya benar-benar
/// berubah, bukan tiap menit saat [outsideHoursProvider] memperbarui diri.
///
/// Selama emisi pertama belum tiba (satu mikrotask saat aplikasi dibuka),
/// nilainya dianggap "di dalam jam". Bila ternyata di luar jam, koneksi yang
/// sempat dibuat langsung ditutup begitu status sebenarnya diketahui — jauh
/// sebelum langganan `subscribeAll` terkirim.
final isOutsideHoursProvider = Provider<bool>((ref) {
  return ref.watch(
    outsideHoursProvider.select((async) => async.valueOrNull ?? false),
  );
});

/// Aliran daftar bus terbaru.
///
/// Di luar jam operasional selalu kosong, walaupun server tetap mengirim posisi
/// bus. Ini menjadi satu gerbang agar tidak ada informasi bus live yang tampil
/// (hitungan bus aktif, kartu pinned, kartu bus di rute, dan notifikasi follow).
final busesProvider = StreamProvider<List<Bus>>((ref) {
  if (ref.watch(isOutsideHoursProvider)) return Stream.value(const <Bus>[]);
  return ref.watch(busSourceProvider).busStream;
});

/// Aliran status koneksi.
///
/// Di luar jam operasional provider ini tidak membaca [busSourceProvider] (yang
/// akan membuka socket), jadi statusnya langsung "outsideHours". Karena itu
/// tidak ada lagi koneksi yang menganggur sepanjang malam.
final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  if (ref.watch(isOutsideHoursProvider)) {
    return Stream.value(ConnectionStatus.outsideHours);
  }
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

/// Koridor yang disaring di layar peta (null = semua koridor).
///
/// Sengaja terpisah dari [selectedCorridorProvider]: tab beranda dan filter
/// peta adalah dua hal berbeda. Membuka peta dari detail bus mempersempit peta
/// ke koridor bus itu tanpa mengubah tab yang sedang dilihat di beranda.
/// Saat peta dibuka biasa, nilai ini di-seed dari tab beranda (lihat
/// `HomeScreen._openMap`).
final mapCorridorProvider = StateProvider<String?>((ref) => null);

/// Bus yang sedang diikuti via notifikasi foreground service.
/// Nilai berupa kunci `'<koridor>|<nomorBus>'` (null = tidak mengikuti).
final followedBusProvider = StateProvider<String?>((ref) => null);

/// Apakah ada bus yang sedang dipilih (diketuk) di layar peta.
///
/// Dipakai [PinnedBusOverlay] untuk menyembunyikan kartu bus di-pin global
/// selama kartu bus peta tampil, agar keduanya tidak saling menumpuk.
final mapBusSelectedProvider = StateProvider<bool>((ref) => false);

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
    throw const LocationException(LocationErrorKind.serviceDisabled);
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    throw const LocationException(LocationErrorKind.permissionDenied);
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationException(LocationErrorKind.permissionDeniedForever);
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
      if (bus.corridor.isNotEmpty) bus.corridor.toUpperCase(),
  };
  final sorted = corridors.toList()..sort();
  return sorted;
});

/// Koridor untuk tab di Home: gabungan K1–K6 dari dataset dengan koridor yang
/// benar-benar mengirim data. Dengan begitu tab tidak "hilang" hanya karena
/// suatu koridor sedang tidak punya bus aktif.
final homeCorridorsProvider = Provider<List<String>>((ref) {
  final dataset = ref.watch(allCorridorsProvider);
  final live = ref.watch(availableCorridorsProvider);
  final codes = <String>{...dataset, ...live};
  final sorted = codes.toList()..sort();
  return sorted;
});

/// Seluruh koridor dari dataset halte bawaan (K1–K6, terurut). Dipakai sebagai
/// sumber tab saat di luar jam operasional, agar pengguna tetap bisa membuka
/// info tiap koridor walau tidak ada bus yang beroperasi.
final allCorridorsProvider = Provider<List<String>>((ref) {
  final dataset = ref.watch(halteDatasetProvider).valueOrNull;
  if (dataset == null) return const [];
  return dataset.corridors.keys.toList()..sort();
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
    String? destinationLabel;
    if (dataset != null) {
      final progress = HalteTracker.track(
        bus,
        dataset,
        estimatedHeading: estimated,
      );
      if (progress != null) {
        destinationLabel = progress.destinationLabel;
      }
    }

    result.add(BusWithDistance.compute(
      bus,
      location,
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

/// Sumber tile peta (ubin OpenStreetMap). Dipisah sebagai provider agar dapat
/// di-override saat pengujian dengan sumber lokal tanpa permintaan jaringan.
///
/// `autoDispose` supaya tiap sesi peta memakai [NetworkTileProvider] baru:
/// [TileLayer] menutup HTTP client milik provider saat peta ditutup, sehingga
/// provider bersama akan mati permanen dan membuat peta kosong saat dibuka lagi.
final tileProviderProvider = Provider.autoDispose<TileProvider>(
  (ref) => NetworkTileProvider(),
);

/// Penanda bus untuk peta, mengikuti koridor yang sedang disaring di peta
/// ([mapCorridorProvider]; null = semua koridor).
final busMapMarkersProvider = Provider<List<BusMapMarker>>((ref) {
  final buses = ref.watch(busesProvider).valueOrNull ?? const <Bus>[];
  return buildBusMapMarkers(
    buses,
    filterCorridor: ref.watch(mapCorridorProvider),
  );
});

/// Geometri jalur koridor (mengikuti jalan) dari hasil bangkitan otomatis
/// (`scripts/generate_corridor_routes.ps1`).
final corridorRouteDatasetProvider =
    FutureProvider<CorridorRouteDataset>((ref) => loadCorridorRouteDataset());

/// Geometri jalur koridor yang digambar manual (GeoJSON di `assets/routes/`).
/// Diprioritaskan di atas [corridorRouteDatasetProvider].
final manualCorridorRouteProvider = FutureProvider<CorridorRouteDataset>(
    (ref) => loadManualCorridorRouteDataset());

/// Halte fisik unik untuk peta (hasil penggabungan pergi/pulang & lintas
/// koridor). Lihat [buildMapStops].
final mapStopsProvider = Provider<List<MapStop>>((ref) {
  final dataset = ref.watch(halteDatasetProvider).valueOrNull;
  if (dataset == null) return const [];
  return buildMapStops(dataset);
});

/// Jalur koridor (polilin) yang digambar di peta.
///
/// Saat sebuah koridor dipilih di peta ([mapCorridorProvider]), hanya koridor
/// itu yang digambar (pergi & pulang). Saat "Semua" (null), seluruh koridor
/// ditampilkan sekaligus — masing-masing memakai warna koridornya. Prioritas
/// geometri: gambar manual > hasil routing > garis antar-halte.
final corridorPathsProvider = Provider<List<CorridorPath>>((ref) {
  final dataset = ref.watch(halteDatasetProvider).valueOrNull;
  if (dataset == null) return const [];
  return buildCorridorPaths(
    dataset,
    filterCorridor: ref.watch(mapCorridorProvider),
    routeGeometry: overlayRouteGeometry(
      ref.watch(manualCorridorRouteProvider).valueOrNull,
      ref.watch(corridorRouteDatasetProvider).valueOrNull,
    ),
  );
});
