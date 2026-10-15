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
  /// Aplikasi aktif layanan pukul 05.00 hingga 20.00 WIB.
  /// Di luar jam ini (20.00 - 05.00 WIB), penanda status berubah menjadi ungu
  /// "Layanan sedang tidak tersedia" karena bus tidak beroperasi.
  static const int operationalStartHour = 5; // 05.00
  static const int operationalEndHour = 20; // 20.00 (eksklusif)

  /// Benar bila [time] jatuh di luar jam operasional TransPadang menurut WIB.
  ///
  /// Dipakai lapisan tampilan untuk menyembunyikan daftar bus dan menampilkan
  /// penanda "layanan sedang tidak melayani penumpang" di luar jam operasional.
  static bool isOutsideOperationalHours(DateTime time) {
    final wib = time.toUtc().add(const Duration(hours: wibOffsetHours));
    return wib.hour < operationalStartHour || wib.hour >= operationalEndHour;
  }
  

  /// Mode pengembangan (data bus palsu) kini **preferensi pengguna**, bukan
  /// lagi flag build: nilainya default mati dan diatur dari layar Pengaturan
  /// (tersimpan lewat `SettingsStore`, lihat `lib/core/settings.dart`).

  /// Offset zona waktu WIB dari UTC.
  static const int wibOffsetHours = 7;

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

  /// Access token Mapbox. Diisi saat build:
  ///   flutter build apk --dart-define=MAPBOX_TOKEN=pk.xxxx
  /// Bila kosong, pencarian otomatis memakai Nominatim (OpenStreetMap).
  static const String mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

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
}
