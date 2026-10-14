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
