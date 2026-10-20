import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id')
  ];

  /// No description provided for @statusConnectedShort.
  ///
  /// In id, this message translates to:
  /// **'Terhubung'**
  String get statusConnectedShort;

  /// No description provided for @statusConnecting.
  ///
  /// In id, this message translates to:
  /// **'Menyambung…'**
  String get statusConnecting;

  /// No description provided for @statusReconnecting.
  ///
  /// In id, this message translates to:
  /// **'Menyambung ulang…'**
  String get statusReconnecting;

  /// No description provided for @statusPillDisconnected.
  ///
  /// In id, this message translates to:
  /// **'Tidak terhubung'**
  String get statusPillDisconnected;

  /// No description provided for @statusWaiting.
  ///
  /// In id, this message translates to:
  /// **'Menunggu…'**
  String get statusWaiting;

  /// No description provided for @statusOutsideHoursShort.
  ///
  /// In id, this message translates to:
  /// **'Di luar jam operasional'**
  String get statusOutsideHoursShort;

  /// No description provided for @tooltipReload.
  ///
  /// In id, this message translates to:
  /// **'Muat ulang'**
  String get tooltipReload;

  /// No description provided for @reloading.
  ///
  /// In id, this message translates to:
  /// **'Memuat ulang data bus…'**
  String get reloading;

  /// No description provided for @searchDestinationHint.
  ///
  /// In id, this message translates to:
  /// **'Cari tujuan…'**
  String get searchDestinationHint;

  /// No description provided for @outsideHoursTitle.
  ///
  /// In id, this message translates to:
  /// **'Sedang tidak melayani penumpang'**
  String get outsideHoursTitle;

  /// No description provided for @outsideHoursMessage.
  ///
  /// In id, this message translates to:
  /// **'TransPadang beroperasi pukul 06.00–19.00 WIB.'**
  String get outsideHoursMessage;

  /// No description provided for @noBusesMessage.
  ///
  /// In id, this message translates to:
  /// **'Belum ada bus terdeteksi di sekitar Anda.'**
  String get noBusesMessage;

  /// No description provided for @gettingLocation.
  ///
  /// In id, this message translates to:
  /// **'Mendapatkan lokasi…'**
  String get gettingLocation;

  /// No description provided for @retry.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get retry;

  /// No description provided for @locationErrorTitle.
  ///
  /// In id, this message translates to:
  /// **'Lokasi tidak tersedia'**
  String get locationErrorTitle;

  /// No description provided for @locationServiceOffTitle.
  ///
  /// In id, this message translates to:
  /// **'GPS nonaktif'**
  String get locationServiceOffTitle;

  /// No description provided for @locationServiceOffMessage.
  ///
  /// In id, this message translates to:
  /// **'Aktifkan GPS perangkat agar jarak dan ETA bus bisa dihitung.'**
  String get locationServiceOffMessage;

  /// No description provided for @locationPermissionTitle.
  ///
  /// In id, this message translates to:
  /// **'Izin lokasi diperlukan'**
  String get locationPermissionTitle;

  /// No description provided for @locationPermissionMessage.
  ///
  /// In id, this message translates to:
  /// **'Izinkan akses lokasi agar jarak dan ETA bus bisa dihitung.'**
  String get locationPermissionMessage;

  /// No description provided for @locationPermissionForeverMessage.
  ///
  /// In id, this message translates to:
  /// **'Izin lokasi ditolak permanen. Aktifkan dari Pengaturan aplikasi.'**
  String get locationPermissionForeverMessage;

  /// No description provided for @locationOpenSettings.
  ///
  /// In id, this message translates to:
  /// **'Buka Pengaturan'**
  String get locationOpenSettings;

  /// No description provided for @locationEnable.
  ///
  /// In id, this message translates to:
  /// **'Aktifkan lokasi'**
  String get locationEnable;

  /// No description provided for @planPickStopInstead.
  ///
  /// In id, this message translates to:
  /// **'Pilih halte sebagai asal'**
  String get planPickStopInstead;

  /// No description provided for @busesConnecting.
  ///
  /// In id, this message translates to:
  /// **'Menyambung ke server…'**
  String get busesConnecting;

  /// No description provided for @busesReconnecting.
  ///
  /// In id, this message translates to:
  /// **'Menyambung ulang ke server…'**
  String get busesReconnecting;

  /// No description provided for @busesDisconnected.
  ///
  /// In id, this message translates to:
  /// **'Tidak terhubung ke server bus.'**
  String get busesDisconnected;

  /// No description provided for @busesEmptyCorridor.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada bus di koridor {corridor} saat ini.'**
  String busesEmptyCorridor(String corridor);

  /// No description provided for @mapTitle.
  ///
  /// In id, this message translates to:
  /// **'Peta Jaringan'**
  String get mapTitle;

  /// No description provided for @mapOpen.
  ///
  /// In id, this message translates to:
  /// **'Lihat peta'**
  String get mapOpen;

  /// No description provided for @mapRecenter.
  ///
  /// In id, this message translates to:
  /// **'Ke lokasi saya'**
  String get mapRecenter;

  /// No description provided for @mapAttribution.
  ///
  /// In id, this message translates to:
  /// **'© OpenStreetMap contributors'**
  String get mapAttribution;

  /// No description provided for @mapStopServedBy.
  ///
  /// In id, this message translates to:
  /// **'Dilayani oleh'**
  String get mapStopServedBy;

  /// No description provided for @mapStopSemantics.
  ///
  /// In id, this message translates to:
  /// **'Halte {name}'**
  String mapStopSemantics(String name);

  /// No description provided for @destinationHeader.
  ///
  /// In id, this message translates to:
  /// **'Tujuan {destination}'**
  String destinationHeader(String destination);

  /// No description provided for @loadingHalteData.
  ///
  /// In id, this message translates to:
  /// **'Memuat data halte…'**
  String get loadingHalteData;

  /// No description provided for @notifFollowingTitle.
  ///
  /// In id, this message translates to:
  /// **'Bus dilacak'**
  String get notifFollowingTitle;

  /// No description provided for @notifFollowingBody.
  ///
  /// In id, this message translates to:
  /// **'TPLive mulai melacak {bus}.'**
  String notifFollowingBody(String bus);

  /// No description provided for @notifApproachBoardTitle.
  ///
  /// In id, this message translates to:
  /// **'Bus segera tiba'**
  String get notifApproachBoardTitle;

  /// No description provided for @notifApproachBoardBody.
  ///
  /// In id, this message translates to:
  /// **'Bus {bus} tinggal {count} halte lagi menuju halte {halte}. Siap-siap naik.'**
  String notifApproachBoardBody(String bus, int count, String halte);

  /// No description provided for @notifAtBoardTitle.
  ///
  /// In id, this message translates to:
  /// **'Waktunya naik'**
  String get notifAtBoardTitle;

  /// No description provided for @notifAtBoardBody.
  ///
  /// In id, this message translates to:
  /// **'Bus {bus} sudah di halte {halte}. Segera naik.'**
  String notifAtBoardBody(String bus, String halte);

  /// No description provided for @notifApproachAlightTitle.
  ///
  /// In id, this message translates to:
  /// **'Sebentar lagi turun'**
  String get notifApproachAlightTitle;

  /// No description provided for @notifApproachAlightBody.
  ///
  /// In id, this message translates to:
  /// **'Bus {bus} tinggal {count} halte lagi menuju halte {halte}. Siap-siap turun.'**
  String notifApproachAlightBody(String bus, int count, String halte);

  /// No description provided for @notifAtAlightTitle.
  ///
  /// In id, this message translates to:
  /// **'Waktunya turun'**
  String get notifAtAlightTitle;

  /// No description provided for @notifAtAlightBody.
  ///
  /// In id, this message translates to:
  /// **'Bus {bus} sudah sampai di halte {halte}. Saatnya turun.'**
  String notifAtAlightBody(String bus, String halte);

  /// No description provided for @tooltipUnfollow.
  ///
  /// In id, this message translates to:
  /// **'Berhenti mengikuti'**
  String get tooltipUnfollow;

  /// No description provided for @tooltipFollow.
  ///
  /// In id, this message translates to:
  /// **'Ikuti bus ini'**
  String get tooltipFollow;

  /// No description provided for @tooltipViewOnMap.
  ///
  /// In id, this message translates to:
  /// **'Lihat di peta'**
  String get tooltipViewOnMap;

  /// No description provided for @tooltipClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get tooltipClose;

  /// No description provided for @notifPermissionDenied.
  ///
  /// In id, this message translates to:
  /// **'Izin notifikasi ditolak. Izinkan notifikasi untuk mengikuti bus.'**
  String get notifPermissionDenied;

  /// No description provided for @notifFollowTitle.
  ///
  /// In id, this message translates to:
  /// **'Bus {bus} · Koridor {corridor}'**
  String notifFollowTitle(String bus, String corridor);

  /// No description provided for @notifFollowTitleGeneric.
  ///
  /// In id, this message translates to:
  /// **'Mengikuti bus {corridor}'**
  String notifFollowTitleGeneric(String corridor);

  /// No description provided for @notifHeadingTo.
  ///
  /// In id, this message translates to:
  /// **'Menuju {stop}'**
  String notifHeadingTo(String stop);

  /// No description provided for @notifDistanceToNext.
  ///
  /// In id, this message translates to:
  /// **'{distance} ke halte berikutnya'**
  String notifDistanceToNext(String distance);

  /// No description provided for @notifEta.
  ///
  /// In id, this message translates to:
  /// **' · ±{minutes} mnt'**
  String notifEta(String minutes);

  /// No description provided for @notifSearchingNext.
  ///
  /// In id, this message translates to:
  /// **'Mencari halte berikutnya…'**
  String get notifSearchingNext;

  /// No description provided for @notifSearchingSignal.
  ///
  /// In id, this message translates to:
  /// **'Mencari sinyal bus…'**
  String get notifSearchingSignal;

  /// No description provided for @notifDestinationFallback.
  ///
  /// In id, this message translates to:
  /// **'Ikuti bus hingga tiba di tujuan'**
  String get notifDestinationFallback;

  /// No description provided for @notifStopAction.
  ///
  /// In id, this message translates to:
  /// **'Berhenti'**
  String get notifStopAction;

  /// No description provided for @notifStopFallback.
  ///
  /// In id, this message translates to:
  /// **'Halte {index}'**
  String notifStopFallback(String index);

  /// No description provided for @notifChannelName.
  ///
  /// In id, this message translates to:
  /// **'Mengikuti bus'**
  String get notifChannelName;

  /// No description provided for @notifChannelDescription.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi posisi bus yang sedang diikuti'**
  String get notifChannelDescription;

  /// No description provided for @notifEventChannelName.
  ///
  /// In id, this message translates to:
  /// **'Kedatangan bus'**
  String get notifEventChannelName;

  /// No description provided for @notifEventChannelDescription.
  ///
  /// In id, this message translates to:
  /// **'Pemberitahuan kedatangan bus yang diikuti'**
  String get notifEventChannelDescription;

  /// No description provided for @followFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengikuti bus: {message}'**
  String followFailed(String message);

  /// No description provided for @followUnavailable.
  ///
  /// In id, this message translates to:
  /// **'Layanan follow tidak tersedia.'**
  String get followUnavailable;

  /// No description provided for @busLabel.
  ///
  /// In id, this message translates to:
  /// **'Bus {number}'**
  String busLabel(String number);

  /// No description provided for @destinationLabel.
  ///
  /// In id, this message translates to:
  /// **'Tujuan {destination}'**
  String destinationLabel(String destination);

  /// No description provided for @updatedLabel.
  ///
  /// In id, this message translates to:
  /// **'Diperbarui {age}'**
  String updatedLabel(String age);

  /// No description provided for @etaApprox.
  ///
  /// In id, this message translates to:
  /// **'≈ {minutes} mnt'**
  String etaApprox(int minutes);

  /// No description provided for @etaUnknown.
  ///
  /// In id, this message translates to:
  /// **'≈ -'**
  String get etaUnknown;

  /// No description provided for @etaPlusMinus.
  ///
  /// In id, this message translates to:
  /// **'± {minutes} mnt'**
  String etaPlusMinus(int minutes);

  /// No description provided for @filterAll.
  ///
  /// In id, this message translates to:
  /// **'Semua'**
  String get filterAll;

  /// No description provided for @ageSeconds.
  ///
  /// In id, this message translates to:
  /// **'{seconds} dtk lalu'**
  String ageSeconds(int seconds);

  /// No description provided for @ageMinutes.
  ///
  /// In id, this message translates to:
  /// **'{minutes} mnt lalu'**
  String ageMinutes(int minutes);

  /// No description provided for @ageHours.
  ///
  /// In id, this message translates to:
  /// **'{hours} jam lalu'**
  String ageHours(int hours);

  /// No description provided for @halteDataLoadFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal memuat data halte.\n{error}'**
  String halteDataLoadFailed(String error);

  /// No description provided for @countHalte.
  ///
  /// In id, this message translates to:
  /// **'{count} halte'**
  String countHalte(int count);

  /// No description provided for @countHalteRange.
  ///
  /// In id, this message translates to:
  /// **'{origin} → {destination} · {count} dari {total} halte'**
  String countHalteRange(String origin, String destination, int count, int total);

  /// No description provided for @currentAt.
  ///
  /// In id, this message translates to:
  /// **'Sedang di'**
  String get currentAt;

  /// No description provided for @nextHalte.
  ///
  /// In id, this message translates to:
  /// **'Halte berikutnya'**
  String get nextHalte;

  /// No description provided for @unknown.
  ///
  /// In id, this message translates to:
  /// **'Tidak diketahui'**
  String get unknown;

  /// No description provided for @etaSuffix.
  ///
  /// In id, this message translates to:
  /// **' · ≈ {minutes} mnt'**
  String etaSuffix(int minutes);

  /// No description provided for @speedUnit.
  ///
  /// In id, this message translates to:
  /// **'km/j'**
  String get speedUnit;

  /// No description provided for @badgeBoard.
  ///
  /// In id, this message translates to:
  /// **'Naik'**
  String get badgeBoard;

  /// No description provided for @badgeAlight.
  ///
  /// In id, this message translates to:
  /// **'Turun'**
  String get badgeAlight;

  /// No description provided for @badgeStart.
  ///
  /// In id, this message translates to:
  /// **'Awal'**
  String get badgeStart;

  /// No description provided for @badgeEnd.
  ///
  /// In id, this message translates to:
  /// **'Akhir'**
  String get badgeEnd;

  /// No description provided for @halteUnavailable.
  ///
  /// In id, this message translates to:
  /// **'Data halte untuk koridor {corridor} belum tersedia.'**
  String halteUnavailable(String corridor);

  /// No description provided for @notPassedHalte.
  ///
  /// In id, this message translates to:
  /// **'Belum melewati halte'**
  String get notPassedHalte;

  /// No description provided for @arrivedDestination.
  ///
  /// In id, this message translates to:
  /// **'Tiba di tujuan'**
  String get arrivedDestination;

  /// No description provided for @lastHalte.
  ///
  /// In id, this message translates to:
  /// **'Halte terakhir'**
  String get lastHalte;

  /// No description provided for @halteRemaining.
  ///
  /// In id, this message translates to:
  /// **'{count} halte lagi'**
  String halteRemaining(int count);

  /// No description provided for @infoNetworkTitle.
  ///
  /// In id, this message translates to:
  /// **'Info Jaringan TransPadang'**
  String get infoNetworkTitle;

  /// No description provided for @infoStatNoActiveBuses.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada bus aktif'**
  String get infoStatNoActiveBuses;

  /// No description provided for @infoStatActiveBuses.
  ///
  /// In id, this message translates to:
  /// **'{count} bus aktif'**
  String infoStatActiveBuses(int count);

  /// No description provided for @infoStatCorridors.
  ///
  /// In id, this message translates to:
  /// **'{count} koridor'**
  String infoStatCorridors(int count);

  /// No description provided for @infoStatHaltes.
  ///
  /// In id, this message translates to:
  /// **'{count} halte'**
  String infoStatHaltes(int count);

  /// No description provided for @infoCorridorTitleCode.
  ///
  /// In id, this message translates to:
  /// **'Koridor {code}'**
  String infoCorridorTitleCode(String code);

  /// No description provided for @infoOperationalHours.
  ///
  /// In id, this message translates to:
  /// **'Jam operasional 06.00–19.00 WIB'**
  String get infoOperationalHours;

  /// No description provided for @infoDataDisclaimer.
  ///
  /// In id, this message translates to:
  /// **'Data halte dapat berbeda dengan kondisi terkini di lapangan.'**
  String get infoDataDisclaimer;

  /// No description provided for @infoActiveBusesLabel.
  ///
  /// In id, this message translates to:
  /// **'Bus aktif'**
  String get infoActiveBusesLabel;

  /// No description provided for @infoTotalStopsLabel.
  ///
  /// In id, this message translates to:
  /// **'Total halte'**
  String get infoTotalStopsLabel;

  /// No description provided for @infoUniqueStopsLabel.
  ///
  /// In id, this message translates to:
  /// **'Halte unik'**
  String get infoUniqueStopsLabel;

  /// No description provided for @infoDirectionPergi.
  ///
  /// In id, this message translates to:
  /// **'Pergi'**
  String get infoDirectionPergi;

  /// No description provided for @infoDirectionPulang.
  ///
  /// In id, this message translates to:
  /// **'Pulang'**
  String get infoDirectionPulang;

  /// No description provided for @infoAllCorridorsTitle.
  ///
  /// In id, this message translates to:
  /// **'Info Semua Koridor'**
  String get infoAllCorridorsTitle;

  /// No description provided for @infoAllCorridorsHint.
  ///
  /// In id, this message translates to:
  /// **'Ketuk koridor untuk melihat detail halte dan arah perjalanannya.'**
  String get infoAllCorridorsHint;

  /// No description provided for @infoAllCorridorsEmpty.
  ///
  /// In id, this message translates to:
  /// **'Data koridor belum tersedia.'**
  String get infoAllCorridorsEmpty;

  /// No description provided for @infoFareTitle.
  ///
  /// In id, this message translates to:
  /// **'Tarif & Pembayaran'**
  String get infoFareTitle;

  /// No description provided for @infoFarePaymentHint.
  ///
  /// In id, this message translates to:
  /// **'Pembayaran dapat menggunakan'**
  String get infoFarePaymentHint;

  /// No description provided for @infoFareGeneral.
  ///
  /// In id, this message translates to:
  /// **'Umum'**
  String get infoFareGeneral;

  /// No description provided for @infoFareStudent.
  ///
  /// In id, this message translates to:
  /// **'Pelajar (SD, SMP, SMA)'**
  String get infoFareStudent;

  /// No description provided for @infoFareChildOver5.
  ///
  /// In id, this message translates to:
  /// **'Anak di atas 5 tahun (tanpa seragam sekolah)'**
  String get infoFareChildOver5;

  /// No description provided for @infoFareChildUnder5.
  ///
  /// In id, this message translates to:
  /// **'Anak di bawah 5 tahun'**
  String get infoFareChildUnder5;

  /// No description provided for @infoFareNote.
  ///
  /// In id, this message translates to:
  /// **'Pembayaran berlaku 2 kali setiap melewati halte terakhir & transit beda koridor.'**
  String get infoFareNote;

  /// No description provided for @searchDestinationTitle.
  ///
  /// In id, this message translates to:
  /// **'Cari tujuan'**
  String get searchDestinationTitle;

  /// No description provided for @pickOriginTitle.
  ///
  /// In id, this message translates to:
  /// **'Pilih asal'**
  String get pickOriginTitle;

  /// No description provided for @pickDestinationTitle.
  ///
  /// In id, this message translates to:
  /// **'Pilih tujuan'**
  String get pickDestinationTitle;

  /// No description provided for @fieldFrom.
  ///
  /// In id, this message translates to:
  /// **'Dari'**
  String get fieldFrom;

  /// No description provided for @fieldTo.
  ///
  /// In id, this message translates to:
  /// **'Ke'**
  String get fieldTo;

  /// No description provided for @hintPickOrigin.
  ///
  /// In id, this message translates to:
  /// **'Pilih asal'**
  String get hintPickOrigin;

  /// No description provided for @hintPickDestination.
  ///
  /// In id, this message translates to:
  /// **'Pilih tujuan'**
  String get hintPickDestination;

  /// No description provided for @planChooseDestination.
  ///
  /// In id, this message translates to:
  /// **'Pilih tujuan lewat tombol \"Ke\" (pilih halte atau cari tempat).'**
  String get planChooseDestination;

  /// No description provided for @planWaitingLocation.
  ///
  /// In id, this message translates to:
  /// **'Menunggu lokasi Anda…'**
  String get planWaitingLocation;

  /// No description provided for @planCalculating.
  ///
  /// In id, this message translates to:
  /// **'Menghitung rute…'**
  String get planCalculating;

  /// No description provided for @planNoRoute.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada rute TransPadang yang cocok antara kedua titik ini.'**
  String get planNoRoute;

  /// No description provided for @minutesApprox.
  ///
  /// In id, this message translates to:
  /// **'≈ {minutes} mnt'**
  String minutesApprox(int minutes);

  /// No description provided for @routeSummary.
  ///
  /// In id, this message translates to:
  /// **'{distance} · {haltes} halte'**
  String routeSummary(String distance, int haltes);

  /// No description provided for @routeSummaryTransit.
  ///
  /// In id, this message translates to:
  /// **' · {count} transit'**
  String routeSummaryTransit(int count);

  /// No description provided for @routeSummaryDirect.
  ///
  /// In id, this message translates to:
  /// **' · langsung'**
  String get routeSummaryDirect;

  /// No description provided for @stepWalkToBoard.
  ///
  /// In id, this message translates to:
  /// **'Jalan {distance} ke halte {halte}'**
  String stepWalkToBoard(String distance, String halte);

  /// No description provided for @stepRide.
  ///
  /// In id, this message translates to:
  /// **'{corridor}: naik di {board} → turun di {alight} ({count} halte)'**
  String stepRide(String corridor, String board, String alight, int count);

  /// No description provided for @stepWalkTransfer.
  ///
  /// In id, this message translates to:
  /// **'Jalan {distance} ke halte {halte}, lanjut Koridor {corridor}'**
  String stepWalkTransfer(String distance, String halte, String corridor);

  /// No description provided for @stepTransfer.
  ///
  /// In id, this message translates to:
  /// **'Pindah ke Koridor {corridor} di {halte}'**
  String stepTransfer(String corridor, String halte);

  /// No description provided for @stepWalkToDestination.
  ///
  /// In id, this message translates to:
  /// **'Jalan {distance} ke tujuan'**
  String stepWalkToDestination(String distance);

  /// No description provided for @noBusesToBoard.
  ///
  /// In id, this message translates to:
  /// **'Belum ada bus terdeteksi menuju halte naik.'**
  String get noBusesToBoard;

  /// No description provided for @nearestBusesToBoard.
  ///
  /// In id, this message translates to:
  /// **'Bus terdekat ke halte naik'**
  String get nearestBusesToBoard;

  /// No description provided for @tapCardHint.
  ///
  /// In id, this message translates to:
  /// **'Ketuk kartu untuk detail halte, ikon lonceng untuk mengikuti.'**
  String get tapCardHint;

  /// No description provided for @tabHalte.
  ///
  /// In id, this message translates to:
  /// **'Halte'**
  String get tabHalte;

  /// No description provided for @tabPlace.
  ///
  /// In id, this message translates to:
  /// **'Tempat'**
  String get tabPlace;

  /// No description provided for @searchPlaceHint.
  ///
  /// In id, this message translates to:
  /// **'Cari tempat, mis. Masjid Raya'**
  String get searchPlaceHint;

  /// No description provided for @searchHalteHint.
  ///
  /// In id, this message translates to:
  /// **'Cari halte…'**
  String get searchHalteHint;

  /// No description provided for @tooltipSearch.
  ///
  /// In id, this message translates to:
  /// **'Cari'**
  String get tooltipSearch;

  /// No description provided for @halteNotFound.
  ///
  /// In id, this message translates to:
  /// **'Halte tidak ditemukan.'**
  String get halteNotFound;

  /// No description provided for @nearestHaltesFromYou.
  ///
  /// In id, this message translates to:
  /// **'Halte terdekat dari lokasi Anda'**
  String get nearestHaltesFromYou;

  /// No description provided for @allHaltes.
  ///
  /// In id, this message translates to:
  /// **'Semua halte'**
  String get allHaltes;

  /// No description provided for @myLocation.
  ///
  /// In id, this message translates to:
  /// **'Lokasi saya'**
  String get myLocation;

  /// No description provided for @myLocationSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Gunakan posisi GPS perangkat saat ini'**
  String get myLocationSubtitle;

  /// No description provided for @favoritesTitle.
  ///
  /// In id, this message translates to:
  /// **'Favorit'**
  String get favoritesTitle;

  /// No description provided for @recentsTitle.
  ///
  /// In id, this message translates to:
  /// **'Terbaru'**
  String get recentsTitle;

  /// No description provided for @addFavorite.
  ///
  /// In id, this message translates to:
  /// **'Tambah ke favorit'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In id, this message translates to:
  /// **'Hapus dari favorit'**
  String get removeFavorite;

  /// No description provided for @placeMinChars.
  ///
  /// In id, this message translates to:
  /// **'Ketik nama tempat (minimal 3 huruf), lalu tekan cari.'**
  String get placeMinChars;

  /// No description provided for @placeNotFound.
  ///
  /// In id, this message translates to:
  /// **'Tempat tidak ditemukan di sekitar Padang.'**
  String get placeNotFound;

  /// No description provided for @placeSearchError.
  ///
  /// In id, this message translates to:
  /// **'Terjadi kesalahan saat mencari tempat.'**
  String get placeSearchError;

  /// No description provided for @placeSearchTimeout.
  ///
  /// In id, this message translates to:
  /// **'Pencarian memakan waktu terlalu lama. Periksa koneksi internet.'**
  String get placeSearchTimeout;

  /// No description provided for @placeSearchNoConnection.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada koneksi internet.'**
  String get placeSearchNoConnection;

  /// No description provided for @placeSearchInvalidResponse.
  ///
  /// In id, this message translates to:
  /// **'Respons pencarian tidak valid.'**
  String get placeSearchInvalidResponse;

  /// No description provided for @placeSearchHttp.
  ///
  /// In id, this message translates to:
  /// **'Pencarian gagal (HTTP {status}). Coba lagi nanti.'**
  String placeSearchHttp(int status);

  /// No description provided for @settingsTooltip.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan'**
  String get settingsTooltip;

  /// No description provided for @settingsTitle.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan'**
  String get settingsTitle;

  /// No description provided for @sectionAppearance.
  ///
  /// In id, this message translates to:
  /// **'Tampilan'**
  String get sectionAppearance;

  /// No description provided for @themeSystem.
  ///
  /// In id, this message translates to:
  /// **'Sistem'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In id, this message translates to:
  /// **'Terang'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In id, this message translates to:
  /// **'Gelap'**
  String get themeDark;

  /// No description provided for @themeModeTitle.
  ///
  /// In id, this message translates to:
  /// **'Mode tampilan'**
  String get themeModeTitle;

  /// No description provided for @dynamicColorTitle.
  ///
  /// In id, this message translates to:
  /// **'Warna dinamis'**
  String get dynamicColorTitle;

  /// No description provided for @dynamicColorSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Ikuti warna wallpaper perangkat (Android 12+)'**
  String get dynamicColorSubtitle;

  /// No description provided for @sectionLanguage.
  ///
  /// In id, this message translates to:
  /// **'Bahasa'**
  String get sectionLanguage;

  /// No description provided for @languageTitle.
  ///
  /// In id, this message translates to:
  /// **'Bahasa aplikasi'**
  String get languageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In id, this message translates to:
  /// **'Sistem'**
  String get languageSystem;

  /// No description provided for @languageIndonesian.
  ///
  /// In id, this message translates to:
  /// **'Indonesia'**
  String get languageIndonesian;

  /// No description provided for @languageEnglish.
  ///
  /// In id, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @sectionAbout.
  ///
  /// In id, this message translates to:
  /// **'Tentang'**
  String get sectionAbout;

  /// No description provided for @aboutVersion.
  ///
  /// In id, this message translates to:
  /// **'Versi {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutAppDescription.
  ///
  /// In id, this message translates to:
  /// **'TPLive menampilkan posisi bus TransPadang secara real-time.'**
  String get aboutAppDescription;

  /// No description provided for @aboutDisclaimer.
  ///
  /// In id, this message translates to:
  /// **'TPLive bukan aplikasi resmi TransPadang maupun Pemerintah Kota Padang. Aplikasi ini dikembangkan semata-mata untuk memudahkan pengguna TransPadang.'**
  String get aboutDisclaimer;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'id': return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
