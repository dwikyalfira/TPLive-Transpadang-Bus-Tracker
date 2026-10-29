import 'app_localizations.dart';

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get statusConnectedShort => 'Connected';

  @override
  String get statusConnecting => 'Connecting…';

  @override
  String get statusReconnecting => 'Reconnecting…';

  @override
  String get statusPillDisconnected => 'Not connected';

  @override
  String get statusWaiting => 'Waiting…';

  @override
  String get statusOutsideHoursShort => 'Outside operating hours';

  @override
  String get tooltipReload => 'Reload';

  @override
  String get reloading => 'Reloading bus data…';

  @override
  String get searchDestinationHint => 'Search destination…';

  @override
  String get outsideHoursTitle => 'Not serving passengers';

  @override
  String get outsideHoursMessage => 'TransPadang operates 06.00–19.00 WIB.';

  @override
  String get noBusesMessage => 'No buses detected around you yet.';

  @override
  String get gettingLocation => 'Getting your location…';

  @override
  String get retry => 'Try again';

  @override
  String get locationErrorTitle => 'Location unavailable';

  @override
  String get locationServiceOffTitle => 'GPS is off';

  @override
  String get locationServiceOffMessage => 'Turn on your device GPS so bus distances and ETAs can be calculated.';

  @override
  String get locationPermissionTitle => 'Location permission required';

  @override
  String get locationPermissionMessage => 'Allow location access so bus distances and ETAs can be calculated.';

  @override
  String get locationPermissionForeverMessage => 'Location permission was permanently denied. Enable it in the app settings.';

  @override
  String get locationOpenSettings => 'Open settings';

  @override
  String get locationEnable => 'Turn on location';

  @override
  String get planPickStopInstead => 'Choose a stop as origin';

  @override
  String get busesConnecting => 'Connecting to the server…';

  @override
  String get busesReconnecting => 'Reconnecting to the server…';

  @override
  String get busesDisconnected => 'Not connected to the bus server.';

  @override
  String busesEmptyCorridor(String corridor) {
    return 'No buses on corridor $corridor right now.';
  }

  @override
  String get mapTitle => 'Network Map';

  @override
  String get mapOpen => 'View map';

  @override
  String get mapRecenter => 'My location';

  @override
  String get mapAttribution => '© OpenStreetMap contributors';

  @override
  String get mapAttributionMapbox => '© Mapbox © OpenStreetMap';

  @override
  String get mapModeTitle => 'Map style';

  @override
  String get mapModeTheme => 'Follow theme';

  @override
  String get mapModeLight => 'Light';

  @override
  String get mapModeDark => 'Dark';

  @override
  String get mapModeSatellite => 'Satellite';

  @override
  String get mapFocusBus => 'Focus on bus';

  @override
  String get mapStopServedBy => 'Served by';

  @override
  String mapStopSemantics(String name) {
    return 'Stop $name';
  }

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
  String get tooltipViewOnMap => 'View on map';

  @override
  String get tooltipClose => 'Close';

  @override
  String get notifPermissionDenied => 'Notification permission denied. Allow notifications to follow a bus.';

  @override
  String notifFollowTitle(String bus, String corridor) {
    return 'Bus $bus · Corridor $corridor';
  }

  @override
  String notifFollowTitleGeneric(String corridor) {
    return 'Following bus $corridor';
  }

  @override
  String notifHeadingTo(String stop) {
    return 'Heading to $stop';
  }

  @override
  String notifDistanceToNext(String distance) {
    return '$distance to the next stop';
  }

  @override
  String notifEta(String minutes) {
    return ' · ±$minutes min';
  }

  @override
  String get notifSearchingNext => 'Finding the next stop…';

  @override
  String get notifSearchingSignal => 'Searching for bus signal…';

  @override
  String get notifDestinationFallback => 'Follow the bus until you reach your destination';

  @override
  String get notifStopAction => 'Stop';

  @override
  String notifStopFallback(String index) {
    return 'Stop $index';
  }

  @override
  String get notifChannelName => 'Following a bus';

  @override
  String get notifChannelDescription => 'Notification for the bus you are following';

  @override
  String get notifEventChannelName => 'Bus arrivals';

  @override
  String get notifEventChannelDescription => 'Alerts for the bus you are following';

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
  String arrivalEta(int minutes) {
    return '≈ $minutes min to your location';
  }

  @override
  String arrivalEtaShort(int minutes) {
    return '≈ $minutes min';
  }

  @override
  String get arrivalNear => 'Bus is near your location';

  @override
  String get arrivalHereShort => 'nearby';

  @override
  String get pinnedCardMinimize => 'Minimize card';

  @override
  String get mapFilterTitle => 'Filter corridors';

  @override
  String get infoNetworkTitle => 'TransPadang network info';

  @override
  String get infoStatNoActiveBuses => 'No active buses';

  @override
  String infoStatActiveBuses(int count) {
    return '$count active buses';
  }

  @override
  String infoStatCorridors(int count) {
    return '$count corridors';
  }

  @override
  String infoStatHaltes(int count) {
    return '$count stops';
  }

  @override
  String infoCorridorTitleCode(String code) {
    return 'Corridor $code';
  }

  @override
  String get infoOperationalHours => 'Operating hours 06.00–19.00 WIB';

  @override
  String get infoDataDisclaimer => 'Stop data may differ from current conditions on the ground.';

  @override
  String get infoActiveBusesLabel => 'Active buses';

  @override
  String get infoTotalStopsLabel => 'Total stops';

  @override
  String get infoUniqueStopsLabel => 'Unique stops';

  @override
  String get infoDirectionPergi => 'Outbound';

  @override
  String get infoDirectionPulang => 'Return';

  @override
  String get infoAllCorridorsTitle => 'All corridors info';

  @override
  String get infoAllCorridorsHint => 'Tap a corridor to see its stops and travel directions.';

  @override
  String get infoAllCorridorsEmpty => 'Corridor data is not available yet.';

  @override
  String get infoFareTitle => 'Fares & Payment';

  @override
  String get infoFarePaymentHint => 'Payment accepted via';

  @override
  String get infoFareGeneral => 'General';

  @override
  String get infoFareStudent => 'Students (elementary, middle, high school)';

  @override
  String get infoFareChildOver5 => 'Children over 5 (without school uniform)';

  @override
  String get infoFareChildUnder5 => 'Children under 5';

  @override
  String get infoFareNote => 'The fare is charged twice each time you pass the last stop and when transferring between corridors.';

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
  String get favoritesTitle => 'Favorites';

  @override
  String get recentsTitle => 'Recent';

  @override
  String get homeLocationSet => 'Set home location';

  @override
  String get homeLocationPickTitle => 'Choose home location';

  @override
  String get homeLocationRoute => 'Route home';

  @override
  String get homeLocationChange => 'Change home location';

  @override
  String get homeLocationRemove => 'Remove home location';

  @override
  String get homeLocationRemoved => 'Home location removed.';

  @override
  String get homeLocationSaved => 'Home location saved.';

  @override
  String get homeLocationUndo => 'Undo';

  @override
  String get addFavorite => 'Add to favorites';

  @override
  String get removeFavorite => 'Remove from favorites';

  @override
  String get placeMinChars => 'Type a place name (at least 3 letters), then press search.';

  @override
  String get placeNotFound => 'No place found around Padang.';

  @override
  String get placeSearchError => 'An error occurred while searching for places.';

  @override
  String get placeSearchTimeout => 'Search is taking too long. Check your internet connection.';

  @override
  String get placeSearchNoConnection => 'No internet connection.';

  @override
  String get placeSearchInvalidResponse => 'Invalid search response.';

  @override
  String placeSearchHttp(int status) {
    return 'Search failed (HTTP $status). Try again later.';
  }

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
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutAppDescription => 'TPLive shows TransPadang bus positions in real time.';

  @override
  String get aboutDisclaimer => 'TPLive is not an official app of TransPadang or the Padang City Government. It is developed purely to make it easier for TransPadang riders.';
}
