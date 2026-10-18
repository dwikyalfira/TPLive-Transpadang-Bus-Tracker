import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/config.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../data/bus_model.dart';
import '../../../domain/bus_with_distance.dart';
import '../../../domain/halte_tracker.dart';
import '../../../domain/map_marker.dart';
import '../../providers.dart';
import '../bus_tile.dart';
import '../floating_pinned_bus_card.dart';
import '../follow_bus_button.dart';
import '../format.dart';
import '../halte_timeline_sheet.dart';

/// Peta live TransPadang: ubin OpenStreetMap, penanda bus (warna koridor +
/// nomor bus), penanda lokasi pengguna, dan tombol kembali ke lokasi pengguna.
///
/// Mengetuk penanda bus memilihnya dan menampilkan kartu ringkas di bagian
/// bawah layar (bukan langsung membuka detail), sehingga bus lain tetap
/// terlihat. Ketuk kartu untuk membuka detail halte ([showBusTimeline]).
class BusMapView extends ConsumerStatefulWidget {
  const BusMapView({super.key});

  @override
  ConsumerState<BusMapView> createState() => _BusMapViewState();
}

class _BusMapViewState extends ConsumerState<BusMapView> {
  final MapController _controller = MapController();

  /// Wadah provider yang ditangkap saat init, dipakai di [dispose] (setelah
  /// `ref` milik State tak lagi boleh dipakai).
  late final ProviderContainer _container;

  /// Peta hanya dipusatkan ke lokasi pengguna satu kali saat lokasi pertama
  /// masuk, supaya geseran/zoom pengguna tidak langsung dilawan.
  bool _centeredOnUser = false;

  /// Kunci bus terpilih (`'<koridor>|<nomor>'`), null = tidak ada.
  String? _selectedKey;

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
    // Mengganti penyaring koridor membatalkan pilihan (bus bisa tidak tampil).
    ref.listenManual(selectedCorridorProvider, (_, __) {
      if (mounted) _applySelection(null);
    });
  }

  void _centerOn(LatLng target) {
    _controller.move(target, AppConfig.mapInitialZoom);
  }

  void _select(BusMapMarker marker) {
    _applySelection('${marker.corridor}|${marker.number}');
  }

  void _clearSelection() => _applySelection(null);

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
    final key = _selectedKey;
    if (key == null) return null;
    final buses = ref.watch(busesProvider).valueOrNull ?? const <Bus>[];
    final filter = ref.watch(selectedCorridorProvider)?.toUpperCase();
    final location = ref.watch(userLocationProvider).valueOrNull;
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
    final userLocation = ref.watch(userLocationProvider).valueOrNull;
    final selected = _selectedItem();
    final dataset = ref.watch(halteDatasetProvider).valueOrNull;
    final HalteProgress? progress = (selected != null && dataset != null)
        ? HalteTracker.track(
            selected.bus,
            dataset,
            estimatedHeading: selected.bus.heading,
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
            onTap: (_, __) => _clearSelection(),
          ),
          children: [
            TileLayer(
              urlTemplate: AppConfig.osmTileUrl,
              userAgentPackageName: AppConfig.osmUserAgent,
              tileProvider: ref.watch(tileProviderProvider),
            ),
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
                    strokeWidth: 4,
                    borderColor: theme.colorScheme.surface,
                    borderStrokeWidth: 1,
                  ),
              ],
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
                TextSourceAttribution(l10n.mapAttribution),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: FloatingActionButton.small(
                      heroTag: 'mapRecenter',
                      tooltip: l10n.mapRecenter,
                      onPressed: userLocation == null
                          ? null
                          : () => _centerOn(userLocation),
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                ),
                if (selected != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: progress != null
                        // Kartu bergaya sama dengan kartu bus yang di-pin,
                        // ditambah rincian ala detail bus (kecepatan, tujuan,
                        // waktu pembaruan). Ketuk kartu membuka detail halte.
                        ? PinnedBusCardBody(
                            bus: selected.bus,
                            progress: progress,
                            onTap: () => showBusTimeline(context, selected),
                            onClose: _clearSelection,
                            footer: PinnedBusCardFooter(
                              bus: selected.bus,
                              destinationLabel: selected.destinationLabel,
                              trailing: FollowBusButton(
                                bus: selected.bus,
                                activeColor:
                                    corridorAccent(selected.bus.corridor, theme),
                                payload: FollowPayload(
                                  originLabel: progress.originLabel,
                                  destinationLabel: progress.destinationLabel,
                                  route: selected.bus.route,
                                  directionKey: progress.arahKey,
                                  haltes: progress.direction.halte,
                                ),
                              ),
                            ),
                          )
                        // Bila data halte belum siap, jatuh ke kartu daftar biasa.
                        : BusTile(
                            item: selected,
                            onTap: () => showBusTimeline(context, selected),
                            trailing: _CloseButton(onClose: _clearSelection),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Marker _busMarker(BusMapMarker marker) {
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
}

/// Penanda bus di peta: lingkaran berwarna koridor berisi nomor bus, dengan
/// panah arah gerak bila heading tersedia.
class _BusMarkerPin extends StatelessWidget {
  final Color color;
  final double? heading;
  final String label;

  const _BusMarkerPin({
    required this.color,
    required this.heading,
    required this.label,
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
