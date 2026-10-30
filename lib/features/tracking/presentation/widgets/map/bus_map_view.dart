import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/config.dart';
import '../../../../../core/theme/app_motion.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../data/bus_model.dart';
import '../../../domain/bus_with_distance.dart';
import '../../../domain/halte_tracker.dart';
import '../../../domain/map_marker.dart';
import '../../../domain/map_stop.dart';
import '../../../domain/user_arrival.dart';
import '../../providers.dart';
import '../bus_tile.dart';
import '../floating_pinned_bus_card.dart';
import '../follow_bus_button.dart';
import '../format.dart';
import '../halte_timeline_sheet.dart';
import 'map_stop_sheet.dart';

/// Peta live TransPadang: ubin OpenStreetMap, penanda bus (warna koridor +
/// nomor bus), penanda lokasi pengguna, dan tombol kembali ke lokasi pengguna.
///
/// Mengetuk penanda bus memilihnya dan menampilkan kartu ringkas di bagian
/// bawah layar (bukan langsung membuka detail), sehingga bus lain tetap
/// terlihat. Ketuk kartu untuk membuka detail halte ([showBusTimeline]).
class BusMapView extends ConsumerStatefulWidget {
  /// Kunci bus yang langsung difokuskan saat peta dibuka (`'<koridor>|<nomor>'`).
  ///
  /// Dipakai saat peta dibuka dari detail bus: peta dipersempit ke koridor bus
  /// itu (garis + bus sekoridor), terpusat ke bus tersebut (zoom
  /// [AppConfig.mapFocusZoom]), penandanya disorot, dan kartu bus di bagian
  /// bawah langsung tampil.
  final String? focusBusKey;

  const BusMapView({super.key, this.focusBusKey});

  @override
  ConsumerState<BusMapView> createState() => BusMapViewState();
}

class BusMapViewState extends ConsumerState<BusMapView> {
  final MapController _controller = MapController();

  /// Wadah provider yang ditangkap saat init, dipakai di [dispose] (setelah
  /// `ref` milik State tak lagi boleh dipakai).
  late final ProviderContainer _container;

  /// Peta hanya dipusatkan ke lokasi pengguna satu kali saat lokasi pertama
  /// masuk, supaya geseran/zoom pengguna tidak langsung dilawan.
  bool _centeredOnUser = false;

  /// Kunci bus terpilih (`'<koridor>|<nomor>'`), null = tidak ada.
  String? _selectedKey;

  /// Id halte terpilih ([MapStop.id]) yang diberi cincin sorot, null = tidak
  /// ada.
  String? _selectedStopId;

  /// Peta sudah siap menerima perintah [MapController.move] (`onMapReady`).
  bool _mapReady = false;

  /// Bus fokus sudah dipusatkan sekali; jangan lawan geseran pengguna.
  bool _didFocus = false;

  static String _keyOf(Bus bus) => '${bus.corridor}|${bus.number}';

  @override
  void dispose() {
    _controller.dispose();
    // Lepas penanda agar kartu pin global kembali tampil begitu keluar peta.
    _container.read(mapBusSelectedProvider.notifier).state = false;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);

    final focus = widget.focusBusKey;
    if (focus != null) {
      _selectedKey = focus;
      // Jangan pusatkan ke GPS saat pengguna meminta melihat bus tertentu.
      _centeredOnUser = true;

      // Data bus bisa tiba setelah peta siap; pusatkan begitu busnya tersedia.
      ref.listenManual(busesProvider, (_, __) {
        if (mounted) _tryFocus();
      });

      // Penulisan provider tidak boleh terjadi saat initState (pohon masih
      // dibangun), jadi tunda satu frame. Listener filter baru didaftarkan
      // setelahnya agar perubahan fokus awal tidak membatalkan pilihannya.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyFocus();
        _listenCorridorChanges();
      });
    } else {
      // Mengganti penyaring koridor membatalkan pilihan (bus bisa tidak tampil).
      _listenCorridorChanges();
    }
  }

  /// Mengganti penyaring koridor peta membatalkan pilihan bus (bus bisa tidak
  /// tampil lagi).
  void _listenCorridorChanges() {
    ref.listenManual(mapCorridorProvider, (_, __) {
      if (mounted) _applySelection(null);
    });
  }

  /// Menetapkan pilihan bus fokus & mempersempit peta ke koridornya.
  void _applyFocus() {
    final focus = widget.focusBusKey;
    if (focus == null) return;

    // Peta dari detail bus menampilkan koridor bus itu saja (garis + bus
    // sekoridor), bukan seluruh jaringan. Filternya milik peta sendiri, jadi
    // tab yang sedang dilihat di beranda tidak ikut berubah.
    final corridor = focus.split('|').first.toUpperCase();
    _container.read(mapCorridorProvider.notifier).state = corridor;

    // Sembunyikan kartu pin global selama kartu bus peta tampil.
    _container.read(mapBusSelectedProvider.notifier).state = true;
  }

  /// Memusatkan peta ke bus fokus sekali saja, saat peta & datanya siap.
  void _tryFocus() {
    if (_didFocus || !_mapReady) return;
    final key = widget.focusBusKey;
    if (key == null) return;
    for (final bus in ref.read(busesProvider).valueOrNull ?? const <Bus>[]) {
      if (_keyOf(bus) != key) continue;
      _didFocus = true;
      _controller.move(bus.position, AppConfig.mapFocusZoom);
      return;
    }
  }

  void _centerOn(LatLng target) {
    _controller.move(target, AppConfig.mapInitialZoom);
  }

  /// Memusatkan peta ke bus yang sedang dipilih (tombol "fokus ke bus" di
  /// kanan-bawah peta).
  ///
  /// Memakai `ref.read` karena dijalankan dari callback, bukan dari `build`.
  /// Tidak melakukan apa pun bila tidak ada bus terpilih atau busnya sudah
  /// hilang dari data live.
  void _focusSelectedBus() {
    final item = _matchSelected(
      ref.read(busesProvider).valueOrNull ?? const <Bus>[],
      _selectedKey,
      ref.read(mapCorridorProvider)?.toUpperCase(),
      ref.read(mapUserLocationProvider),
    );
    if (item == null || !_mapReady) return;
    _controller.move(item.bus.position, AppConfig.mapFocusZoom);
  }

  void _select(BusMapMarker marker) {
    _applySelection('${marker.corridor}|${marker.number}');
  }

  void _clearSelection() {
    _applySelection(null);
    if (_selectedStopId != null) {
      setState(() => _selectedStopId = null);
    }
  }

  /// Menutup baris penyaring koridor (koridor terpilih tidak diubah).
  ///
  /// Memakai `_container` (bukan `ref`) karena dipanggil dari callback
  /// flutter_map yang bisa tiba tepat saat widget dibuang.
  void _collapseFilter() {
    if (!mounted) return;
    if (!_container.read(mapFilterExpandedProvider)) return;
    _container.read(mapFilterExpandedProvider.notifier).state = false;
  }

  /// Melipat kartu status "sedang tidak melayani penumpang" jadi ikon saja.
  ///
  /// Dipanggil saat peta diketuk: begitu pengguna mulai menelusuri peta, bilah
  /// informasi selebar layar hanya menghalangi. Teksnya bisa dibuka lagi dengan
  /// mengetuk ikon bulan di kiri-atas (lihat `_OutsideHoursStatus`).
  void _collapseStatusCard() {
    if (!mounted) return;
    if (!_container.read(mapStatusExpandedProvider)) return;
    _container.read(mapStatusExpandedProvider.notifier).state = false;
  }

  void _openStop(MapStop stop) {
    if (_selectedStopId != stop.id) {
      setState(() => _selectedStopId = stop.id);
    }
    showMapStopSheet(context, stop);
  }

  /// Menetapkan bus terpilih sekaligus menandai status pilihan ke provider,
  /// supaya kartu pin global menyembunyikan diri selama kartu peta tampil.
  void _applySelection(String? key) {
    if (_selectedKey != key) {
      setState(() => _selectedKey = key);
    }
    ref.read(mapBusSelectedProvider.notifier).state = key != null;
  }

  /// Bus terpilih versi live (non-basi & lolos penyaring koridor), atau null
  /// bila tidak ada / sudah tidak tampil.
  BusWithDistance? _selectedItem() {
    return _matchSelected(
      ref.watch(busesProvider).valueOrNull ?? const <Bus>[],
      _selectedKey,
      ref.watch(mapCorridorProvider)?.toUpperCase(),
      ref.watch(mapUserLocationProvider),
    );
  }

  /// Mencari bus ber-[key] di antara [buses] (murni, tanpa `ref`).
  ///
  /// Dipakai baik oleh `build` (lewat [ref.watch]) maupun oleh callback tombol
  /// (lewat [ref.read]) supaya keduanya memakai aturan penyaringan yang sama:
  /// bus basi dan bus di luar koridor terpilih dianggap tidak ada.
  static BusWithDistance? _matchSelected(
    List<Bus> buses,
    String? key,
    String? filter,
    LatLng? location,
  ) {
    if (key == null) return null;
    final nowUtc = DateTime.now().toUtc();
    for (final bus in buses) {
      if (_keyOf(bus) != key || bus.isStale(nowUtc)) continue;
      if (filter != null && bus.corridor.toUpperCase() != filter) continue;
      return BusWithDistance.compute(bus, location ?? bus.position);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final markers = ref.watch(busMapMarkersProvider);
    final userLocation = ref.watch(mapUserLocationProvider);
    final selected = _selectedItem();
    final tileSource = ref.watch(
      mapTileSourceProvider(theme.brightness == Brightness.dark),
    );
    final dataset = ref.watch(halteDatasetProvider).valueOrNull;
    final HalteProgress? progress = (selected != null && dataset != null)
        ? HalteTracker.trackStable(
            selected.bus,
            dataset,
            estimatedHeading: selected.bus.heading,
          )
        : null;

    // Estimasi bus terpilih datang ke lokasi pengguna (null bila GPS belum ada).
    final arrival = (selected != null && userLocation != null)
        ? UserArrival.estimate(
            busPosition: selected.bus.position,
            user: userLocation,
            speedKmh: selected.bus.speedKmh,
          )
        : null;

    if (!_centeredOnUser && userLocation != null) {
      _centeredOnUser = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centerOn(userLocation);
      });
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: userLocation ??
                const LatLng(AppConfig.mapInitialLat, AppConfig.mapInitialLng),
            initialZoom: AppConfig.mapInitialZoom,
            minZoom: 10,
            maxZoom: 18,
            backgroundColor: theme.colorScheme.surface,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            // Peta belum bisa digeser lewat controller sebelum siap; di sinilah
            // bus fokus dipusatkan (termasuk bila datanya baru tiba).
            onMapReady: () {
              _mapReady = true;
              _tryFocus();
            },
            // Geseran/zoom oleh jari pengguna menutup baris penyaring koridor
            // agar peta tidak tertutup saat sedang ditelusuri. Perubahan kamera
            // terprogram (fokus bus, tombol lokasi) tidak ikut menutup karena
            // `hasGesture` false. Kartu status di luar jam operasional ikut
            // dilipat dengan alasan yang sama.
            onPositionChanged: (_, hasGesture) {
              if (!hasGesture) return;
              _collapseFilter();
              _collapseStatusCard();
            },
            onTap: (_, __) {
              _clearSelection();
              _collapseFilter();
              // Mengetuk peta juga menyembunyikan teks status di luar jam
              // operasional; ikonnya tetap ada untuk membuka lagi.
              _collapseStatusCard();
            },
          ),
          children: [
            _tileLayer(tileSource),
            // Jalur koridor (semua koridor saat tab "Semua", atau hanya yang
            // terpilih), digambar di atas ubin namun di bawah penanda agar bus
            // & lokasi pengguna tetap terlihat/diketuk.
            PolylineLayer(
              polylineCulling: true,
              polylines: [
                for (final path in ref.watch(corridorPathsProvider))
                  Polyline(
                    points: path.points,
                    color: corridorAccent(path.corridor, theme),
                    strokeWidth: AppConfig.mapRouteStrokeWidth,
                    borderColor: theme.colorScheme.surface,
                    borderStrokeWidth: AppConfig.mapRouteBorderWidth,
                  ),
              ],
            ),
            // Halte digambar di bawah bus/lokasi pengguna agar penanda bus
            // tetap menang saat diketuk.
            Consumer(
              builder: (context, ref, _) {
                final camera = MapCamera.of(context);
                final stops = ref.watch(mapStopsProvider);
                final filter = ref.watch(mapCorridorProvider);
                return MarkerLayer(
                  markers: _stopMarkers(context, stops, filter, camera.zoom),
                );
              },
            ),
            MarkerLayer(
              markers: [
                // Titik lokasi digambar lebih dulu agar penanda bus selalu di
                // atasnya (dan tetap bisa diketuk walau bus tepat di lokasi).
                if (userLocation != null) _userMarker(userLocation),
                for (final marker in markers) _busMarker(marker),
              ],
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                TextSourceAttribution(
                  tileSource.fromMapbox
                      ? l10n.mapAttributionMapbox
                      : l10n.mapAttribution,
                ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: SafeArea(
            top: false,
            // Tinggi area bawah (tombol + kartu bus) ikut dianimasikan supaya
            // tombol "ke lokasi saya" tidak melompat saat kartu muncul/hilang.
            child: AnimatedSize(
              duration: AppMotion.resolve(context, AppMotion.medium2),
              curve: AppMotion.standard,
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Kontrol peta dikumpulkan di kanan-bawah: "fokus ke bus" (hanya
                  // saat ada bus terpilih) tepat di atas "ke lokasi saya". Dulu
                  // tombol fokus melayang sendiri di kanan-atas dan terlihat
                  // menggantung di tengah peta.
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tombol fokus memudar + membesar masuk, bukan
                          // muncul mendadak begitu bus diketuk.
                          AnimatedSwitcher(
                            duration:
                                AppMotion.resolve(context, AppMotion.short4),
                            switchInCurve: AppMotion.emphasizedDecelerate,
                            switchOutCurve: AppMotion.emphasizedAccelerate,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: animation,
                                child: child,
                              ),
                            ),
                            child: selected == null
                                ? const SizedBox(
                                    key: ValueKey('mapFocusBus:none'),
                                  )
                                : Padding(
                                    key: const ValueKey('mapFocusBus:shown'),
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: FloatingActionButton.small(
                                      heroTag: 'mapFocusBus',
                                      tooltip: l10n.mapFocusBus,
                                      onPressed: _focusSelectedBus,
                                      child: const Icon(
                                          Icons.center_focus_strong),
                                    ),
                                  ),
                          ),
                          FloatingActionButton.small(
                            heroTag: 'mapRecenter',
                            tooltip: l10n.mapRecenter,
                            onPressed: userLocation == null
                                ? null
                                : () => _centerOn(userLocation),
                            child: const Icon(Icons.my_location),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Kartu bus terpilih: memudar + meluncur naik saat dipilih,
                  // dan memudar keluar saat pilihan dibatalkan.
                  AnimatedSwitcher(
                    duration: AppMotion.resolve(context, AppMotion.medium2),
                    reverseDuration:
                        AppMotion.resolve(context, AppMotion.short4),
                    switchInCurve: AppMotion.emphasizedDecelerate,
                    switchOutCurve: AppMotion.emphasizedAccelerate,
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.bottomCenter,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    ),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: selected == null
                        ? const SizedBox(
                            key: ValueKey('mapBusCard:none'),
                            width: double.infinity,
                            height: 0,
                          )
                        : Padding(
                            key: ValueKey(
                              'mapBusCard:${selected.bus.corridor}|'
                              '${selected.bus.number}',
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: progress != null
                                // Kartu bergaya sama dengan kartu bus yang
                                // di-pin, ditambah rincian ala detail bus
                                // (kecepatan, tujuan, waktu pembaruan). Ketuk
                                // kartu membuka detail halte.
                                ? PinnedBusCardBody(
                                    bus: selected.bus,
                                    progress: progress,
                                    onTap: () => showBusTimeline(
                                        context, selected,
                                        fromMap: true),
                                    onClose: _clearSelection,
                                    footer: PinnedBusCardFooter(
                                      bus: selected.bus,
                                      destinationLabel:
                                          selected.destinationLabel,
                                      arrival: arrival,
                                      trailing: FollowBusButton(
                                        bus: selected.bus,
                                        activeColor: corridorAccent(
                                            selected.bus.corridor, theme),
                                        payload: FollowPayload(
                                          originLabel: progress.originLabel,
                                          destinationLabel:
                                              progress.destinationLabel,
                                          route: selected.bus.route,
                                          directionKey: progress.arahKey,
                                          haltes: progress.direction.halte,
                                        ),
                                      ),
                                    ),
                                  )
                                // Bila data halte belum siap, jatuh ke kartu
                                // daftar biasa.
                                : BusTile(
                                    item: selected,
                                    onTap: () => showBusTimeline(
                                        context, selected,
                                        fromMap: true),
                                    trailing: _CloseButton(
                                        onClose: _clearSelection),
                                  ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Marker _busMarker(BusMapMarker marker) {
    // `_selectedKey` null saat tak ada pilihan, jadi tidak perlu cek null.
    final highlight = _selectedKey == '${marker.corridor}|${marker.number}';
    return Marker(
      point: marker.position,
      width: 44,
      height: 44,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(marker),
        child: _BusMarkerPin(
          color: corridorColor(marker.corridor),
          heading: marker.heading,
          label: marker.number,
          highlighted: highlight,
        ),
      ),
    );
  }

  Marker _userMarker(LatLng position) {
    return Marker(
      point: position,
      width: 22,
      height: 22,
      child: const _UserMarkerDot(),
    );
  }

  /// Matriks warna untuk "menggelapkan" ubin OSM saat build tanpa token Mapbox.
  ///
  /// Keluaran = kebalikan luminansi (`255 - luma`), jadi peta jadi gelap tanpa
  /// membalik warna jalan seperti inversi penuh. Ini hanya fallback visual —
  /// dengan token Mapbox mode gelap memakai style `dark-v11` yang asli.
  static const ColorFilter _osmDarkFilter = ColorFilter.matrix(<double>[
    -0.299, -0.587, -0.114, 0, 255, //
    -0.299, -0.587, -0.114, 0, 255, //
    -0.299, -0.587, -0.114, 0, 255, //
    0, 0, 0, 1, 0, //
  ]);

  /// Lapisan ubin peta sesuai [source]; diberi filter gelap bila perlu.
  Widget _tileLayer(MapTileSource source) {
    final layer = TileLayer(
      urlTemplate: source.urlTemplate,
      userAgentPackageName: AppConfig.osmUserAgent,
      tileProvider: ref.watch(tileProviderProvider),
    );
    if (!source.needsDarkFilter) return layer;
    return ColorFiltered(colorFilter: _osmDarkFilter, child: layer);
  }

  /// Zoom minimum untuk menampilkan halte saat penyaring "Semua" aktif.
  ///
  /// Dengan puluhan halte per koridor, menampilkannya di zoom kota membuat peta
  /// penuh titik; saat satu koridor dipilih, haltenya selalu tampil.
  static const double _stopAllMinZoom = 15.5;

  /// Zoom minimum untuk menampilkan label nama halte.
  static const double _stopLabelZoom = 17;

  List<Marker> _stopMarkers(
    BuildContext context,
    List<MapStop> stops,
    String? filter,
    double zoom,
  ) {
    if (stops.isEmpty || (filter == null && zoom < _stopAllMinZoom)) {
      return const [];
    }
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final showLabels = zoom >= _stopLabelZoom;
    final size = zoom >= 14.5 ? (showLabels ? 13.0 : 11.0) : 8.0;
    // Saat satu koridor disaring, hanya halte koridor itu yang digambar.
    final active = filter?.toUpperCase();
    final visible = active == null
        ? stops
        : [
            for (final stop in stops)
              if (stop.corridors.contains(active)) stop,
          ];

    return [
      for (final stop in visible)
        Marker(
          key: ValueKey('mapStop:${stop.id}'),
          point: stop.pos,
          width: showLabels ? _StopMarkerPin.labelWidth : 44,
          height: 44,
          child: _StopMarkerPin(
            name: stop.name,
            color: _stopColor(stop, filter, theme),
            size: size,
            selected: stop.id == _selectedStopId,
            interchange: stop.isInterchange,
            showLabel: showLabels,
            semanticsLabel: l10n.mapStopSemantics(stop.name),
            onTap: () => _openStop(stop),
          ),
        ),
    ];
  }

  /// Warna titik halte: warna koridor yang sedang disaring, warna koridornya
  /// saat hanya satu koridor melayani, dan warna netral untuk halte transit.
  Color _stopColor(MapStop stop, String? filter, ThemeData theme) {
    if (filter != null) return corridorColor(filter);
    if (stop.corridors.length == 1) return corridorColor(stop.corridors.first);
    return theme.colorScheme.onSurfaceVariant;
  }
}

/// Titik halte di peta.
///
/// Area sentuh selalu 44x44 dp meski titiknya kecil; label nama (bila aktif)
/// tidak menerima sentuhan supaya tidak menutupi peta di sekitarnya.
class _StopMarkerPin extends StatelessWidget {
  /// Lebar kotak saat label nama ikut tampil.
  static const double labelWidth = 168;

  final String name;
  final Color color;
  final double size;
  final bool selected;
  final bool interchange;
  final bool showLabel;
  final String semanticsLabel;
  final VoidCallback onTap;

  const _StopMarkerPin({
    required this.name,
    required this.color,
    required this.size,
    required this.selected,
    required this.interchange,
    required this.showLabel,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.colorScheme.surface;
    final dotSize = selected ? size + 5 : size;

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: SizedBox(
        width: showLabel ? labelWidth : 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  // [AnimatedContainer] supaya halte yang dipilih membesar
                  // (dan berganti warna saat filter berubah) dengan halus,
                  // bukan melompat satu frame.
                  child: AnimatedContainer(
                    duration: AppMotion.resolve(context, AppMotion.short4),
                    curve: AppMotion.standard,
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: border, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    // Halte transit diberi inti putih agar mudah dikenali
                    // walau warnanya sama dengan koridor di sekitarnya.
                    child: interchange
                        ? Center(
                            child: Container(
                              width: dotSize * 0.34,
                              height: dotSize * 0.34,
                              decoration: BoxDecoration(
                                color: border,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            if (showLabel)
              Positioned(
                left: labelWidth / 2 + 12,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Center(child: _StopLabel(name: name)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Chip nama halte yang tampil di samping titik saat zoom dekat.
class _StopLabel extends StatelessWidget {
  final String name;

  const _StopLabel({required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Penanda bus di peta: lingkaran berwarna koridor berisi nomor bus, dengan
/// panah arah gerak bila heading tersedia. Saat [highlighted] benar (bus yang
/// diklik dari detail bus), penanda diberi cincin warna koridor.
class _BusMarkerPin extends StatelessWidget {
  final Color color;
  final double? heading;
  final String label;

  /// Beri cincin sorot (bus terpilih/fokus).
  final bool highlighted;

  const _BusMarkerPin({
    required this.color,
    required this.heading,
    required this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final number = label.trim();
    final direction = heading;
    return Semantics(
      label: number.isEmpty ? null : number,
      button: true,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (highlighted)
              // Cincin sorot tumbuh + memudar masuk saat bus dipilih, bukan
              // muncul mendadak. Kuncinya tetap di [Container] dalam supaya
              // pengujian/pembaca layar menemukannya seperti sebelumnya.
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.7, end: 1),
                duration: AppMotion.resolve(context, AppMotion.medium2),
                curve: AppMotion.emphasizedDecelerate,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.scale(scale: t, child: child),
                ),
                child: Container(
                  key: const Key('busMarkerHighlight'),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            if (direction != null)
              Transform.rotate(
                angle: direction * math.pi / 180,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _DirectionArrow(color: color),
                ),
              ),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    number,
                    maxLines: 1,
                    style: TextStyle(
                      color: onColor(color),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panah kecil penunjuk arah gerak bus (di tepi penanda).
class _DirectionArrow extends StatelessWidget {
  final Color color;

  const _DirectionArrow({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.navigation, size: 11, color: color),
    );
  }
}

/// Tombol tutup kartu bus di peta (di ujung kanan kartu).
class _CloseButton extends StatelessWidget {
  final VoidCallback onClose;

  const _CloseButton({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).tooltipClose,
      child: InkResponse(
        onTap: onClose,
        radius: 20,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Icon(
              Icons.close,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Penanda lokasi pengguna: titik berwarna aksen dengan garis tepi putih.
class _UserMarkerDot extends StatelessWidget {
  const _UserMarkerDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
