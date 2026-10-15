import 'app_localizations.dart';

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get statusDemo => 'Development mode';

  @override
  String get statusLive => 'Live';

  @override
  String get statusConnecting => 'Connecting…';

  @override
  String get statusReconnecting => 'Reconnecting…';

  @override
  String get statusPillOutsideHours => 'Service currently unavailable';

  @override
  String get statusPillDisconnected => 'Not connected';

  @override
  String get statusWaiting => 'Waiting…';

  @override
  String get statusOutsideHoursShort => 'Outside operating hours';

  @override
  String get statusDisconnectedShort => 'Disconnected';

  @override
  String get tooltipDemoOn => 'Turn off demo mode';

  @override
  String get tooltipDemoOff => 'Demo mode (fake bus data)';

  @override
  String get tooltipReload => 'Reload';

  @override
  String get reloading => 'Reloading bus data…';

  @override
  String get searchDestinationHint => 'Search destination…';

  @override
  String get outsideHoursTitle => 'Not serving passengers';

  @override
  String get outsideHoursMessage => 'TransPadang operates 05.00–20.00 WIB.';

  @override
  String get noBusesMessage => 'No buses detected around you yet.';

  @override
  String get gettingLocation => 'Getting your location…';

  @override
  String get retry => 'Try again';

  @override
  String destinationHeader(String destination) {
    return 'Toward $destination';
  }

  @override
  String get loadingHalteData => 'Loading stops…';

  @override
  String get notifFollowingTitle => 'Tracking bus';

  @override
  String notifFollowingBody(String bus) {
    return 'TPLive started tracking $bus.';
  }

  @override
  String get notifApproachBoardTitle => 'Bus arriving soon';

  @override
  String notifApproachBoardBody(String bus, int count, String halte) {
    return 'Bus $bus is $count stops away from $halte. Get ready to board.';
  }

  @override
  String get notifAtBoardTitle => 'Time to board';

  @override
  String notifAtBoardBody(String bus, String halte) {
    return 'Bus $bus is at $halte. Board now.';
  }

  @override
  String get notifApproachAlightTitle => 'Approaching your stop';

  @override
  String notifApproachAlightBody(String bus, int count, String halte) {
    return 'Bus $bus is $count stops away from $halte. Get ready to alight.';
  }

  @override
  String get notifAtAlightTitle => 'Time to alight';

  @override
  String notifAtAlightBody(String bus, String halte) {
    return 'Bus $bus has arrived at $halte. Time to get off.';
  }

  @override
  String get tooltipUnfollow => 'Stop following';

  @override
  String get tooltipFollow => 'Follow this bus';

  @override
  String get notifPermissionDenied => 'Notification permission denied. Allow notifications to follow a bus.';

  @override
  String followFailed(String message) {
    return 'Failed to follow bus: $message';
  }

  @override
  String get followUnavailable => 'Follow service unavailable.';

  @override
  String busLabel(String number) {
    return 'Bus $number';
  }

  @override
  String destinationLabel(String destination) {
    return 'Toward $destination';
  }

  @override
  String updatedLabel(String age) {
    return 'Updated $age';
  }

  @override
  String etaApprox(int minutes) {
    return '≈ $minutes min';
  }

  @override
  String get etaUnknown => '≈ -';

  @override
  String etaPlusMinus(int minutes) {
    return '± $minutes min';
  }

  @override
  String get filterAll => 'All';

  @override
  String ageSeconds(int seconds) {
    return '${seconds}s ago';
  }

  @override
  String ageMinutes(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String ageHours(int hours) {
    return '${hours}h ago';
  }

  @override
  String halteDataLoadFailed(String error) {
    return 'Failed to load stop data.\n$error';
  }

  @override
  String countHalte(int count) {
    return '$count stops';
  }

  @override
  String countHalteRange(String origin, String destination, int count, int total) {
    return '$origin → $destination · $count of $total stops';
  }

  @override
  String get currentAt => 'At';

  @override
  String get nextHalte => 'Next stop';

  @override
  String get unknown => 'Unknown';

  @override
  String etaSuffix(int minutes) {
    return ' · ≈ $minutes min';
  }

  @override
  String get speedUnit => 'km/h';

  @override
  String get badgeBoard => 'Board';

  @override
  String get badgeAlight => 'Alight';

  @override
  String get badgeStart => 'Start';

  @override
  String get badgeEnd => 'End';

  @override
  String halteUnavailable(String corridor) {
    return 'Stop data for corridor $corridor is not available yet.';
  }

  @override
  String get notPassedHalte => 'Has not passed a stop yet';

  @override
  String get arrivedDestination => 'Arrived at destination';

  @override
  String get lastHalte => 'Last stop';

  @override
  String halteRemaining(int count) {
    return '$count stops left';
  }

  @override
  String get searchDestinationTitle => 'Search destination';

  @override
  String get pickOriginTitle => 'Choose origin';

  @override
  String get pickDestinationTitle => 'Choose destination';

  @override
  String get fieldFrom => 'From';

  @override
  String get fieldTo => 'To';

  @override
  String get hintPickOrigin => 'Choose origin';

  @override
  String get hintPickDestination => 'Choose destination';

  @override
  String get planChooseDestination => 'Choose a destination via the \"To\" button (pick a stop or search a place).';

  @override
  String get planWaitingLocation => 'Waiting for your location…';

  @override
  String get planCalculating => 'Calculating route…';

  @override
  String get planNoRoute => 'No matching TransPadang route between these two points.';

  @override
  String minutesApprox(int minutes) {
    return '≈ $minutes min';
  }

  @override
  String routeSummary(String distance, int haltes) {
    return '$distance · $haltes stops';
  }

  @override
  String routeSummaryTransit(int count) {
    return ' · $count transfers';
  }

  @override
  String get routeSummaryDirect => ' · direct';

  @override
  String stepWalkToBoard(String distance, String halte) {
    return 'Walk $distance to $halte';
  }

  @override
  String stepRide(String corridor, String board, String alight, int count) {
    return '$corridor: board at $board → alight at $alight ($count stops)';
  }

  @override
  String stepWalkTransfer(String distance, String halte, String corridor) {
    return 'Walk $distance to $halte, continue on Corridor $corridor';
  }

  @override
  String stepTransfer(String corridor, String halte) {
    return 'Transfer to Corridor $corridor at $halte';
  }

  @override
  String stepWalkToDestination(String distance) {
    return 'Walk $distance to destination';
  }

  @override
  String get noBusesToBoard => 'No buses detected heading to the boarding stop yet.';

  @override
  String get nearestBusesToBoard => 'Nearest buses to boarding stop';

  @override
  String get tapCardHint => 'Tap a card for stop details, tap the bell icon to follow.';

  @override
  String get tabHalte => 'Stops';

  @override
  String get tabPlace => 'Places';

  @override
  String get searchPlaceHint => 'Search a place, e.g. Masjid Raya';

  @override
  String get searchHalteHint => 'Search stops…';

  @override
  String get tooltipSearch => 'Search';

  @override
  String get halteNotFound => 'Stop not found.';

  @override
  String get nearestHaltesFromYou => 'Nearest stops from your location';

  @override
  String get allHaltes => 'All stops';

  @override
  String get myLocation => 'My location';

  @override
  String get myLocationSubtitle => 'Use the device\'s current GPS position';

  @override
  String get placeMinChars => 'Type a place name (at least 3 letters), then press search.';

  @override
  String get placeNotFound => 'No place found around Padang.';

  @override
  String get placeSearchError => 'An error occurred while searching for places.';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeModeTitle => 'Display mode';

  @override
  String get dynamicColorTitle => 'Dynamic color';

  @override
  String get dynamicColorSubtitle => 'Follow the device wallpaper (Android 12+)';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get languageTitle => 'App language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageIndonesian => 'Indonesia';

  @override
  String get languageEnglish => 'English';

  @override
  String get sectionAbout => 'About';

  @override
  String get aboutTitle => 'About App';

  @override
  String get aboutAppDescription => 'TPLive shows TransPadang bus positions in real time.';

  @override
  String get demoModeTitle => 'Demo mode';

  @override
  String get demoModeSubtitle => 'Use fake bus data for development';
}
