import 'app_localizations.dart';

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get statusDemo => 'Mode pengembangan';

  @override
  String get statusLive => 'Live';

  @override
  String get statusConnectedShort => 'Terhubung';

  @override
  String get statusConnecting => 'Menyambung…';

  @override
  String get statusReconnecting => 'Menyambung ulang…';

  @override
  String get statusPillOutsideHours => 'Layanan sedang tidak tersedia';

  @override
  String get statusPillDisconnected => 'Tidak terhubung';

  @override
  String get statusWaiting => 'Menunggu…';

  @override
  String get statusOutsideHoursShort => 'Di luar jam operasional';

  @override
  String get statusDisconnectedShort => 'Terputus';

  @override
  String get tooltipDemoOn => 'Matikan mode demo';

  @override
  String get tooltipDemoOff => 'Mode demo (data bus palsu)';

  @override
  String get tooltipReload => 'Muat ulang';

  @override
  String get reloading => 'Memuat ulang data bus…';

  @override
  String get searchDestinationHint => 'Cari tujuan…';

  @override
  String get outsideHoursTitle => 'Sedang tidak melayani penumpang';

  @override
  String get outsideHoursMessage => 'TransPadang beroperasi pukul 05.00–20.00 WIB.';

  @override
  String get noBusesMessage => 'Belum ada bus terdeteksi di sekitar Anda.';

  @override
  String get gettingLocation => 'Mendapatkan lokasi…';

  @override
  String get retry => 'Coba lagi';

  @override
  String destinationHeader(String destination) {
    return 'Tujuan $destination';
  }

  @override
  String get loadingHalteData => 'Memuat data halte…';

  @override
  String get notifFollowingTitle => 'Bus dilacak';

  @override
  String notifFollowingBody(String bus) {
    return 'TPLive mulai melacak $bus.';
  }

  @override
  String get notifApproachBoardTitle => 'Bus segera tiba';

  @override
  String notifApproachBoardBody(String bus, int count, String halte) {
    return 'Bus $bus tinggal $count halte lagi menuju halte $halte. Siap-siap naik.';
  }

  @override
  String get notifAtBoardTitle => 'Waktunya naik';

  @override
  String notifAtBoardBody(String bus, String halte) {
    return 'Bus $bus sudah di halte $halte. Segera naik.';
  }

  @override
  String get notifApproachAlightTitle => 'Sebentar lagi turun';

  @override
  String notifApproachAlightBody(String bus, int count, String halte) {
    return 'Bus $bus tinggal $count halte lagi menuju halte $halte. Siap-siap turun.';
  }

  @override
  String get notifAtAlightTitle => 'Waktunya turun';

  @override
  String notifAtAlightBody(String bus, String halte) {
    return 'Bus $bus sudah sampai di halte $halte. Saatnya turun.';
  }

  @override
  String get tooltipUnfollow => 'Berhenti mengikuti';

  @override
  String get tooltipFollow => 'Ikuti bus ini';

  @override
  String get tooltipClose => 'Tutup';

  @override
  String get notifPermissionDenied => 'Izin notifikasi ditolak. Izinkan notifikasi untuk mengikuti bus.';

  @override
  String followFailed(String message) {
    return 'Gagal mengikuti bus: $message';
  }

  @override
  String get followUnavailable => 'Layanan follow tidak tersedia.';

  @override
  String busLabel(String number) {
    return 'Bus $number';
  }

  @override
  String destinationLabel(String destination) {
    return 'Tujuan $destination';
  }

  @override
  String updatedLabel(String age) {
    return 'Diperbarui $age';
  }

  @override
  String etaApprox(int minutes) {
    return '≈ $minutes mnt';
  }

  @override
  String get etaUnknown => '≈ -';

  @override
  String etaPlusMinus(int minutes) {
    return '± $minutes mnt';
  }

  @override
  String get filterAll => 'Semua';

  @override
  String ageSeconds(int seconds) {
    return '$seconds dtk lalu';
  }

  @override
  String ageMinutes(int minutes) {
    return '$minutes mnt lalu';
  }

  @override
  String ageHours(int hours) {
    return '$hours jam lalu';
  }

  @override
  String halteDataLoadFailed(String error) {
    return 'Gagal memuat data halte.\n$error';
  }

  @override
  String countHalte(int count) {
    return '$count halte';
  }

  @override
  String countHalteRange(String origin, String destination, int count, int total) {
    return '$origin → $destination · $count dari $total halte';
  }

  @override
  String get currentAt => 'Sedang di';

  @override
  String get nextHalte => 'Halte berikutnya';

  @override
  String get unknown => 'Tidak diketahui';

  @override
  String etaSuffix(int minutes) {
    return ' · ≈ $minutes mnt';
  }

  @override
  String get speedUnit => 'km/j';

  @override
  String get badgeBoard => 'Naik';

  @override
  String get badgeAlight => 'Turun';

  @override
  String get badgeStart => 'Awal';

  @override
  String get badgeEnd => 'Akhir';

  @override
  String halteUnavailable(String corridor) {
    return 'Data halte untuk koridor $corridor belum tersedia.';
  }

  @override
  String get notPassedHalte => 'Belum melewati halte';

  @override
  String get arrivedDestination => 'Tiba di tujuan';

  @override
  String get lastHalte => 'Halte terakhir';

  @override
  String halteRemaining(int count) {
    return '$count halte lagi';
  }

  @override
  String get infoNetworkTitle => 'Info Jaringan TransPadang';

  @override
  String get infoStatNoActiveBuses => 'Tidak ada bus aktif';

  @override
  String infoStatActiveBuses(int count) {
    return '$count bus aktif';
  }

  @override
  String infoStatCorridors(int count) {
    return '$count koridor';
  }

  @override
  String infoStatHaltes(int count) {
    return '$count halte';
  }

  @override
  String infoCorridorTitleCode(String code) {
    return 'Koridor $code';
  }

  @override
  String get infoOperationalHours => 'Jam operasional 05.00–20.00 WIB';

  @override
  String get infoDataDisclaimer => 'Data halte dapat berbeda dengan kondisi terkini di lapangan.';

  @override
  String get infoActiveBusesLabel => 'Bus aktif';

  @override
  String get infoTotalStopsLabel => 'Total halte';

  @override
  String get infoUniqueStopsLabel => 'Halte unik';

  @override
  String get infoDirectionPergi => 'Pergi';

  @override
  String get infoDirectionPulang => 'Pulang';

  @override
  String get searchDestinationTitle => 'Cari tujuan';

  @override
  String get pickOriginTitle => 'Pilih asal';

  @override
  String get pickDestinationTitle => 'Pilih tujuan';

  @override
  String get fieldFrom => 'Dari';

  @override
  String get fieldTo => 'Ke';

  @override
  String get hintPickOrigin => 'Pilih asal';

  @override
  String get hintPickDestination => 'Pilih tujuan';

  @override
  String get planChooseDestination => 'Pilih tujuan lewat tombol \"Ke\" (pilih halte atau cari tempat).';

  @override
  String get planWaitingLocation => 'Menunggu lokasi Anda…';

  @override
  String get planCalculating => 'Menghitung rute…';

  @override
  String get planNoRoute => 'Tidak ada rute TransPadang yang cocok antara kedua titik ini.';

  @override
  String minutesApprox(int minutes) {
    return '≈ $minutes mnt';
  }

  @override
  String routeSummary(String distance, int haltes) {
    return '$distance · $haltes halte';
  }

  @override
  String routeSummaryTransit(int count) {
    return ' · $count transit';
  }

  @override
  String get routeSummaryDirect => ' · langsung';

  @override
  String stepWalkToBoard(String distance, String halte) {
    return 'Jalan $distance ke halte $halte';
  }

  @override
  String stepRide(String corridor, String board, String alight, int count) {
    return '$corridor: naik di $board → turun di $alight ($count halte)';
  }

  @override
  String stepWalkTransfer(String distance, String halte, String corridor) {
    return 'Jalan $distance ke halte $halte, lanjut Koridor $corridor';
  }

  @override
  String stepTransfer(String corridor, String halte) {
    return 'Pindah ke Koridor $corridor di $halte';
  }

  @override
  String stepWalkToDestination(String distance) {
    return 'Jalan $distance ke tujuan';
  }

  @override
  String get noBusesToBoard => 'Belum ada bus terdeteksi menuju halte naik.';

  @override
  String get nearestBusesToBoard => 'Bus terdekat ke halte naik';

  @override
  String get tapCardHint => 'Ketuk kartu untuk detail halte, ikon lonceng untuk mengikuti.';

  @override
  String get tabHalte => 'Halte';

  @override
  String get tabPlace => 'Tempat';

  @override
  String get searchPlaceHint => 'Cari tempat, mis. Masjid Raya';

  @override
  String get searchHalteHint => 'Cari halte…';

  @override
  String get tooltipSearch => 'Cari';

  @override
  String get halteNotFound => 'Halte tidak ditemukan.';

  @override
  String get nearestHaltesFromYou => 'Halte terdekat dari lokasi Anda';

  @override
  String get allHaltes => 'Semua halte';

  @override
  String get myLocation => 'Lokasi saya';

  @override
  String get myLocationSubtitle => 'Gunakan posisi GPS perangkat saat ini';

  @override
  String get placeMinChars => 'Ketik nama tempat (minimal 3 huruf), lalu tekan cari.';

  @override
  String get placeNotFound => 'Tempat tidak ditemukan di sekitar Padang.';

  @override
  String get placeSearchError => 'Terjadi kesalahan saat mencari tempat.';

  @override
  String get settingsTooltip => 'Pengaturan';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get sectionAppearance => 'Tampilan';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Terang';

  @override
  String get themeDark => 'Gelap';

  @override
  String get themeModeTitle => 'Mode tampilan';

  @override
  String get dynamicColorTitle => 'Warna dinamis';

  @override
  String get dynamicColorSubtitle => 'Ikuti warna wallpaper perangkat (Android 12+)';

  @override
  String get sectionLanguage => 'Bahasa';

  @override
  String get languageTitle => 'Bahasa aplikasi';

  @override
  String get languageSystem => 'Sistem';

  @override
  String get languageIndonesian => 'Indonesia';

  @override
  String get languageEnglish => 'English';

  @override
  String get sectionAbout => 'Tentang';

  @override
  String get aboutTitle => 'Tentang Aplikasi';

  @override
  String aboutVersion(String version) {
    return 'Versi $version';
  }

  @override
  String get aboutAppDescription => 'TPLive menampilkan posisi bus TransPadang secara real-time.';

  @override
  String get aboutDisclaimer => 'TPLive bukan aplikasi resmi TransPadang maupun Pemerintah Kota Padang. Aplikasi ini dikembangkan semata-mata untuk memudahkan pengguna TransPadang.';

  @override
  String get demoModeTitle => 'Mode demo';

  @override
  String get demoModeSubtitle => 'Gunakan data bus palsu untuk pengembangan';
}
