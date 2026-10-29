/// Konfigurasi terpusat aplikasi TransPadang Live.
class AppConfig {
  AppConfig._();

  /// Endpoint WebSocket realtime posisi bus (tanpa autentikasi).
  static const String wsUrl = 'wss://wstrans.padang.go.id/ws';

  /// Pesan untuk berlangganan semua bus.
  static const String subscribeAllMessage = '{"type":"subscribeAll"}';

  /// Kecepatan default (km/j) bila bus berhenti / kecepatan tidak valid.
  static const double defaultSpeedKmh = 20.0;

  /// Di bawah nilai ini, bus dianggap berhenti -> pakai kecepatan default.
  static const double minMovingSpeedKmh = 5.0;

  /// Batas umur data; lebih dari ini dianggap basi dan disembunyikan.
  static const Duration staleAfter = Duration(minutes: 5);

  /// Jam operasional TransPadang (WIB).
  ///
  /// Aplikasi aktif layanan pukul 06.00 hingga 19.00 WIB.
  /// Di luar jam ini (19.00 - 06.00 WIB), penanda status berubah menjadi ungu
  /// "Layanan sedang tidak tersedia" karena bus tidak beroperasi.
  static const int operationalStartHour = 6; // 06.00
  static const int operationalEndHour = 19; // 19.00 (eksklusif)

  /// Benar bila [time] jatuh di luar jam operasional TransPadang menurut WIB.
  ///
  /// Dipakai lapisan tampilan untuk menyembunyikan daftar bus dan menampilkan
  /// penanda "layanan sedang tidak melayani penumpang" di luar jam operasional.
  static bool isOutsideOperationalHours(DateTime time) {
    final wib = time.toUtc().add(const Duration(hours: wibOffsetHours));
    return wib.hour < operationalStartHour || wib.hour >= operationalEndHour;
  }
  

  /// Offset zona waktu WIB dari UTC.
  static const int wibOffsetHours = 7;

  // --- Peta (tampilan peta live) ---

  /// Template tile raster OpenStreetMap (XYZ, 256 px).
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Identitas aplikasi yang dikirim sebagai User-Agent ke tile server OSM
  /// (wajib sesuai kebijakan penggunaan OSM).
  static const String osmUserAgent = 'id.dwiky.transpadang_live';

  /// Pusat awal peta (Kota Padang) & tingkat zoom awal.
  static const double mapInitialLat = -0.9478;
  static const double mapInitialLng = 100.3543;
  static const double mapInitialZoom = 12.5;

  /// Zoom saat peta dibuka untuk memusatkan satu bus tertentu (dari detail bus).
  static const double mapFocusZoom = 16;

  /// Tebal garis jalur koridor di peta (px layar) + garis batasnya.
  ///
  /// Sengaja tipis: pada zoom 16 skala peta Padang ~2,4 m/px, jadi total
  /// ~3 px hanya menutupi ~7 m. Garis yang lebih tebal (4 px + 1 px batas)
  /// melebar ~12 m sehingga menutupi seluruh jalan dan membuat kedua arah
  /// (berjarak ~10 m) saling menumpuk. Pada ~3 px keduanya masih terpisah
  /// tipis di zoom 16 dan makin jelas di zoom 17 ke atas.
  static const double mapRouteStrokeWidth = 2.5;
  static const double mapRouteBorderWidth = 0.5;

  /// Style raster Mapbox untuk tiap gaya peta (Terang/Gelap/Satelit).
  ///
  /// Memakai token Mapbox yang sama dengan pencarian tempat, sehingga mode
  /// gelap tidak bergantung pada penyedia ubin pihak ketiga.
  static const String mapboxStreetsStyle = 'mapbox/streets-v12';
  static const String mapboxDarkStyle = 'mapbox/dark-v11';
  static const String mapboxSatelliteStyle = 'mapbox/satellite-streets-v12';

  /// Benar bila token Mapbox tersedia sehingga ubin Mapbox dapat dipakai.
  ///
  /// Build tanpa token (`--dart-define=MAPBOX_TOKEN=`) otomatis memakai ubin
  /// OpenStreetMap untuk semua mode.
  static bool get hasMapboxToken => mapboxToken.trim().isNotEmpty;

  /// Template ubin raster XYZ 256 px untuk [style] Mapbox.
  ///
  /// [token] memungkinkan pemakaian token lain (mis. di pengujian yang ingin
  /// menguji jalur "tanpa token"); default-nya token build aplikasi.
  static String mapboxTileUrl(String style, {String? token}) =>
      'https://api.mapbox.com/styles/v1/$style/tiles/256/{z}/{x}/{y}'
      '?access_token=${token ?? mapboxToken}';

  // --- Pencarian tujuan (geocoding Nominatim/OSM) ---

  /// Host layanan geocoding Nominatim (OpenStreetMap).
  static const String geocoderHost = 'nominatim.openstreetmap.org';

  /// User-Agent untuk Nominatim (wajib, sesuai kebijakan penggunaan).
  /// Hindari domain contoh seperti `example.com` — Nominatim memblokirnya (403).
  /// Ganti URL kontak dengan milik Anda bila perlu.
  static const String geocoderUserAgent =
      'TransPadangLive/1.0 (+https://github.com/dwiky/transpadang-live)';

  /// Bahasa hasil geocoding.
  static const String geocoderLanguage = 'id';

  /// Kotak pembatas wilayah Padang (left,top,right,bottom = lon,lat,lon,lat),
  /// agar hasil pencarian dibatasi di sekitar Padang.
  static const String padangViewbox = '100.25,-0.75,100.45,-1.05';

  // --- Pencarian tujuan (Mapbox Search Box API) ---

  /// Host Search Box API Mapbox (mengembalikan POI seperti kafe/toko).
  static const String mapboxSearchHost = 'api.mapbox.com';

  /// Access token Mapbox (public token — memang untuk disertakan di aplikasi
  /// klien). Nilai default disertakan agar pencarian tempat langsung berfungsi;
  /// dapat ditimpa saat build: `--dart-define=MAPBOX_TOKEN=pk.xxxx`. Bila
  /// dikosongkan lewat dart-define, pencarian jatuh ke Nominatim (OpenStreetMap).
  static const String mapboxToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue:
        'pk.eyJ1IjoiZHdpa3lhbGZpcmEiLCJhIjoiY212N3FyMGtoMDF2czJ4b25wN2sweHRvYiJ9.RaXtez6i-paIJxOCpJhcKg',
  );

  /// Kotak pembatas wilayah Padang untuk Mapbox
  /// (minLon,minLat,maxLon,maxLat — urutan berbeda dari Nominatim).
  static const String padangBbox = '100.25,-1.05,100.45,-0.75';

  /// Pusat Padang (lon,lat) untuk membiasakan (bias) hasil pencarian.
  static const String padangProximity = '100.35,-0.95';

  /// Bahasa hasil pencarian Mapbox.
  static const String mapboxLanguage = 'id';

  /// Kode negara (ISO 3166 alpha 2) untuk membatasi hasil.
  static const String mapboxCountry = 'id';

  /// Kecepatan berjalan kaki (km/j) untuk estimasi waktu jalan.
  static const double walkSpeedKmh = 4.5;

  /// Jarak jalan kaki maksimum (km) yang masih dianggap masuk akal. Rute yang
  /// total jalannya melebihi ini tidak disarankan.
  static const double maxWalkKm = 1.5;

  /// Jarak jalan kaki maksimum (km) untuk berpindah bus antar dua halte
  /// berbeda nama yang berdekatan (transfer jalan kaki).
  static const double transferWalkKm = 0.4;

  /// Penalti waktu tiap kali harus pindah bus (menit).
  static const int transferPenaltyMinutes = 8;

  // --- Mode demo (data tiruan, khusus pengembangan) ---

  /// Benar bila aplikasi dijalankan dengan data bus tiruan.
  ///
  ///   flutter run --dart-define=MOCK_BUS=true
  ///   flutter run --dart-define=MOCK_BUS=true \
  ///               --dart-define=MOCK_LOCATION=-0.9478,100.3543
  ///
  /// Bus tiruan bergerak menyusuri halte tiap koridor, jam operasional
  /// diabaikan, dan tidak ada koneksi ke server. Build tanpa flag ini sama
  /// sekali tidak memakai data tiruan.
  static const bool useMockBus = bool.fromEnvironment('MOCK_BUS');

  /// Lokasi pengguna tiruan "lat,lng" untuk mode demo (opsional).
  ///
  /// Berguna saat menguji di emulator/desktop yang tidak punya GPS atau saat
  /// ingin melihat daftar "bus terdekat" dari titik tertentu.
  static const String mockLocationRaw =
      String.fromEnvironment('MOCK_LOCATION');
}
