import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/follow_service.dart';
import '../../../core/ui/constrained_content.dart';
import '../../../core/ui/fade_through_route.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../trip/presentation/trip_providers.dart';
import '../../trip/presentation/trip_screen.dart';
import '../data/bus_model.dart';
import '../data/trans_ws_datasource.dart';
import '../domain/bus_with_distance.dart';
import '../domain/follow_alert_engine.dart';
import '../domain/halte_tracker.dart';
import 'providers.dart';
import 'widgets/bus_tile.dart';
import 'widgets/corridor_info_header.dart';
import 'widgets/corridor_selector.dart';
import 'widgets/format.dart';
import 'widgets/halte_timeline_sheet.dart';
import 'widgets/live_status_pill.dart';
import 'widgets/map/map_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Notifikasi kedatangan bus yang sudah terkirim (kunci dari engine), agar
  /// setiap kejadian hanya berbunyi sekali.
  final Set<String> _firedAlerts = <String>{};

  /// Awal sesi aplikasi; dipakai untuk tidak bersuara saat follow dipulihkan
  /// otomatis (app dibuka lagi, bukan sedang menekan tombol ikuti).
  final DateTime _sessionStartedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _restoreFollow();
    ref.listenManual(followedBusProvider, (_, next) {
      if (next != null) _onBusPinned(next);
    });
    ref.listenManual(busesProvider, (_, async) {
      final buses = async.valueOrNull;
      if (buses == null || ref.read(followedBusProvider) == null) return;
      _evaluateFollowAlerts(buses);
    });
    // Di luar jam operasional, hentikan follow agar tidak ada notifikasi /
    // kartu pinned yang menampilkan bus yang sebenarnya tidak beroperasi.
    ref.listenManual(isOutsideHoursProvider, (_, next) {
      if (next) _stopFollowForOffHours();
    });
  }

  /// Memulihkan indikator "mengikuti" bila foreground service masih aktif
  /// (mis. setelah aplikasi dibuka ulang). Tidak dipulihkan di luar jam
  /// operasional.
  Future<void> _restoreFollow() async {
    if (ref.read(isOutsideHoursProvider)) return;
    final followed = await FollowService.getFollowed();
    if (!mounted || followed == null) return;
    ref.read(followedBusProvider.notifier).state =
        busFollowKey(followed.corridor, followed.busNumber);
  }

  /// Menghentikan sesi "ikuti bus" (indikator + foreground service native).
  void _stopFollowForOffHours() {
    if (ref.read(followedBusProvider) == null) return;
    ref.read(followedBusProvider.notifier).state = null;
    unawaited(FollowService.stopFollow());
  }

  void _onBusPinned(String key) {
    _firedAlerts.clear();
    // Pemulihan otomatis saat app dibuka bukan aksi pengguna → jangan bunyi.
    final isRestore =
        DateTime.now().difference(_sessionStartedAt) < const Duration(seconds: 5);
    if (isRestore) return;
    final bus = _findFollowedBus(key);
    final l10n = AppLocalizations.of(context);
    unawaited(FollowService.showEventNotification(
      id: 9101,
      title: l10n.notifFollowingTitle,
      body: l10n.notifFollowingBody(_busLabel(bus, key)),
    ));
  }

  void _evaluateFollowAlerts(List<Bus> buses) {
    final key = ref.read(followedBusProvider);
    if (key == null) return;
    final bus = _findFollowedBus(key);
    if (bus == null) return;
    final dataset = ref.read(halteDatasetProvider).valueOrNull;
    if (dataset == null) return;
    final progress =
        HalteTracker.track(bus, dataset, estimatedHeading: bus.heading);
    if (progress == null) return;

    final plan = ref.read(tripPlanProvider);
    final idx = progress.currentIndex ?? progress.nextIndex;
    final leg = FollowAlertEngine.matchBoardingLeg(
      legs: plan == null ? const [] : plan.options.expand((o) => o.legs),
      corridor: bus.corridor,
      arahKey: progress.arahKey,
      idx: idx,
    );

    final names = [for (final s in progress.steps) s.halte.nama];
    final candidates = FollowAlertEngine.evaluate(
      nextIndex: progress.nextIndex,
      currentIndex: progress.currentIndex,
      boardIndex: leg?.board,
      alightIndex: leg?.alight,
      halteNames: names,
    );

    for (final candidate in candidates) {
      if (!_firedAlerts.add(candidate.dedupeKey)) continue;
      unawaited(_notify(candidate, bus));
    }
  }

  Future<void> _notify(FollowAlertCandidate candidate, Bus bus) async {
    final l10n = AppLocalizations.of(context);
    final label = _busLabel(bus, null);
    switch (candidate.type) {
      case FollowAlertType.approachingBoard:
        await FollowService.showEventNotification(
          id: 9102,
          title: l10n.notifApproachBoardTitle,
          body: l10n.notifApproachBoardBody(
            label,
            candidate.remaining,
            candidate.halteName,
          ),
        );
      case FollowAlertType.atBoard:
        await FollowService.showEventNotification(
          id: 9103,
          title: l10n.notifAtBoardTitle,
          body: l10n.notifAtBoardBody(label, candidate.halteName),
        );
      case FollowAlertType.approachingAlight:
        await FollowService.showEventNotification(
          id: 9104,
          title: l10n.notifApproachAlightTitle,
          body: l10n.notifApproachAlightBody(
            label,
            candidate.remaining,
            candidate.halteName,
          ),
        );
      case FollowAlertType.atAlight:
        await FollowService.showEventNotification(
          id: 9105,
          title: l10n.notifAtAlightTitle,
          body: l10n.notifAtAlightBody(label, candidate.halteName),
        );
    }
  }

  Bus? _findFollowedBus(String key) {
    final buses = ref.read(busesProvider).valueOrNull;
    if (buses == null) return null;
    for (final bus in buses) {
      if (busFollowKey(bus.corridor, bus.number) == key) return bus;
    }
    return null;
  }

  /// Label tampilan bus: nomor dari server bila ada, fallback ke koridor.
  String _busLabel(Bus? bus, String? key) {
    final number = bus?.number.trim() ?? '';
    if (number.isNotEmpty) return 'Bus $number';
    if (key != null) {
      final parts = key.split('|');
      final corridor = parts.isNotEmpty ? parts.first : key;
      final busNumber = parts.length > 1 ? parts[1] : '';
      return busNumber.isNotEmpty ? 'Bus $corridor-$busNumber' : 'Bus $corridor';
    }
    final corridor = bus?.corridor ?? '';
    return corridor.isNotEmpty ? 'Bus $corridor' : 'bus';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Di luar jam operasional (05:00-20:00 WIB) dihitung provider yang
    // diperbarui tiap menit. Saat true, bilah pencarian & info koridor tetap
    // tampil, tetapi daftar bus diganti info jam operasional (lihat
    // [_BusListView.isOutsideHours]).
    final isOutsideHours = ref.watch(isOutsideHoursProvider);
    final status = ref.watch(connectionStatusProvider).valueOrNull;
    final locationAsync = ref.watch(userLocationProvider);
    final nearby = ref.watch(nearbyBusesProvider);
    // Di luar jam: pakai seluruh koridor dari dataset agar info tiap koridor
    // tetap bisa dibuka walau tidak ada bus beroperasi.
    final corridors = ref.watch(
      isOutsideHours ? allCorridorsProvider : availableCorridorsProvider,
    );

    final listView = _BusListView(
      isOutsideHours: isOutsideHours,
      status: status,
      nearby: nearby,
      corridors: corridors,
      onSearchTap: () => _openTripSearch(context),
      onRefresh: _refresh,
    );

    final Widget body;
    if (isOutsideHours) {
      body = ConstrainedContent(child: listView);
    } else if (locationAsync.hasError) {
      body = ErrorStateView(
        message: locationAsync.error.toString(),
        onRetry: () => ref.invalidate(userLocationProvider),
      );
    } else if (locationAsync.isLoading || !locationAsync.hasValue) {
      body = LoadingStateView(message: l10n.gettingLocation);
    } else {
      body = ConstrainedContent(child: listView);
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TPLive',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            LiveStatusPill(
              status:
                  isOutsideHours ? ConnectionStatus.outsideHours : status,
              onTap: () {},
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.mapOpen,
            icon: const Icon(Icons.map_outlined),
            onPressed: () => _openMap(context),
          ),
          _SpinIconButton(
            tooltip: l10n.tooltipReload,
            icon: Icons.refresh,
            onPressed: _refresh,
          ),
          _SpinIconButton(
            tooltip: l10n.settingsTooltip,
            icon: Icons.settings_outlined,
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: body,
    );
  }

  /// Memuat ulang lokasi & sumber bus. Non-destruktif, jadi cukup diberi umpan
  /// balik singkat (SnackBar) tanpa dialog konfirmasi.
  Future<void> _refresh() async {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.reloading),
        duration: const Duration(seconds: 1),
      ));
    ref.invalidate(userLocationProvider);
    ref.invalidate(busSourceProvider);
    try {
      await ref.read(userLocationProvider.future);
    } catch (_) {
      // Error ditampilkan oleh state lokasi; abaikan di sini.
    }
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(_settingsRoute());
  }

  /// Transisi halus menuju layar Pengaturan: fade-through Material 3.
  Route<void> _settingsRoute() =>
      fadeThroughRoute<void>(builder: (_) => const SettingsScreen());

  void _openTripSearch(BuildContext context) {
    Navigator.of(context).push(_tripSearchRoute());
  }

  /// Transisi halus menuju layar "Cari tujuan": fade-through Material 3.
  Route<void> _tripSearchRoute() =>
      fadeThroughRoute<void>(builder: (_) => const TripScreen());

  void _openMap(BuildContext context) {
    Navigator.of(context).push(_mapRoute());
  }

  /// Transisi halus menuju layar peta: fade-through Material 3.
  Route<void> _mapRoute() =>
      fadeThroughRoute<void>(builder: (_) => const MapScreen());
}

/// Bilah "Cari tujuan" di bagian atas daftar bus. Diketuk untuk membuka
/// perencana perjalanan. Pencarian adalah aksi utama, jadi diberi area yang
/// menonjol di body — bukan sekadar ikon kecil di AppBar.
class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: Color.alphaBlend(
          theme.colorScheme.primary.withOpacity(0.05),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).searchDestinationHint,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                Icon(
                  Icons.travel_explore,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BusListView extends ConsumerStatefulWidget {
  final ConnectionStatus? status;
  final List<BusWithDistance> nearby;
  final List<String> corridors;

  /// Bila benar, area daftar tiap tab diganti info jam operasional (daftar bus
  /// disembunyikan) sementara bilah pencarian, tab koridor, dan kartu info
  /// koridor tetap tampil.
  final bool isOutsideHours;
  final VoidCallback onSearchTap;
  final Future<void> Function() onRefresh;

  const _BusListView({
    required this.status,
    required this.nearby,
    required this.corridors,
    this.isOutsideHours = false,
    required this.onSearchTap,
    required this.onRefresh,
  });

  @override
  ConsumerState<_BusListView> createState() => _BusListViewState();
}

class _BusListViewState extends ConsumerState<_BusListView>
    with SingleTickerProviderStateMixin {
  /// Tab: indeks 0 = "Semua", lalu K1, K2, ... sesuai [widget.corridors].
  /// Tidak `final`: controller dibangun ulang di [didUpdateWidget] saat daftar
  /// koridor berubah (mis. bus pertama kali masuk dari WebSocket).
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: widget.corridors.length + 1,
      vsync: this,
      initialIndex: _indexOf(widget.corridors, ref.read(selectedCorridorProvider))
          .clamp(0, widget.corridors.length),
    );
    _tabs.addListener(_syncSelectedCorridor);
  }

  @override
  void didUpdateWidget(_BusListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.corridors, widget.corridors)) {
      _tabs.removeListener(_syncSelectedCorridor);
      final index = _tabs.index.clamp(0, widget.corridors.length);
      final previous = _tabs;
      _tabs = TabController(
        length: widget.corridors.length + 1,
        vsync: this,
        initialIndex: index,
      );
      _tabs.addListener(_syncSelectedCorridor);
      previous.dispose();
      _syncSelectedCorridor();
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_syncSelectedCorridor);
    _tabs.dispose();
    super.dispose();
  }

  static int _indexOf(List<String> corridors, String? selected) {
    if (selected == null) return 0;
    final index = corridors.indexOf(selected);
    return index < 0 ? 0 : index + 1;
  }

  String? get _selectedCorridor =>
      _tabs.index == 0 ? null : widget.corridors[_tabs.index - 1];

  /// Menyimpan tab terpilih; dipanggil saat pengguna mengetuk ikon koridor
  /// maupun setelah ia menggeser halaman (jadi pilihannya tidak hilang).
  void _syncSelectedCorridor() {
    final selected = _selectedCorridor;
    if (ref.read(selectedCorridorProvider) == selected) return;
    ref.read(selectedCorridorProvider.notifier).state = selected;
  }

  @override
  Widget build(BuildContext context) {
    final corridors = widget.corridors;

    return Column(
      children: [
        _SearchBar(onTap: widget.onSearchTap),
        if (corridors.isEmpty)
          Expanded(child: _page(null))
        else ...[
          _CorridorTabs(controller: _tabs, corridors: corridors),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                for (final corridor in [null, ...corridors]) _page(corridor),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Isi satu halaman tab: kartu "Info Koridor" di atas, lalu daftar bus
  /// milik koridor [corridor] (null = semua koridor).
  Widget _page(String? corridor) {
    final buses = corridor == null
        ? widget.nearby
        : widget.nearby
            .where((b) => b.bus.corridor == corridor)
            .toList(growable: false);
    final key = ValueKey<String>(corridor ?? '__all__');

    final content = widget.isOutsideHours
        ? const _OutsideHoursView()
        : buses.isEmpty
            ? _EmptyState(key: key, status: widget.status)
            : corridor == null
                ? _FlatBusList(key: key, buses: buses)
                : _GroupedBusList(key: key, buses: buses);

    return Column(
      children: [
        CorridorInfoHeader(corridor: corridor),
        Expanded(
          child: widget.isOutsideHours
              ? content
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: content,
                ),
        ),
      ],
    );
  }
}

/// Daftar bus terdekat tanpa pengelompokan (untuk tab "Semua").
class _FlatBusList extends StatelessWidget {
  final List<BusWithDistance> buses;

  const _FlatBusList({super.key, required this.buses});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: buses.length,
      itemBuilder: (context, index) => BusTile(
        item: buses[index],
        onTap: () => showBusTimeline(context, buses[index]),
      ),
    );
  }
}

/// Daftar bus terdekat yang dikelompokkan per tujuan (arah).
class _GroupedBusList extends StatelessWidget {
  final List<BusWithDistance> buses;

  const _GroupedBusList({super.key, required this.buses});

  @override
  Widget build(BuildContext context) {
    // Kelompokkan berurutan sesuai kemunculan (bus terdekat dulu).
    final l10n = AppLocalizations.of(context);
    final corridor = buses.first.bus.corridor;
    final groups = <String, List<BusWithDistance>>{};
    for (final b in buses) {
      final dest = b.destinationLabel ?? l10n.unknown;
      groups.putIfAbsent(dest, () => <BusWithDistance>[]).add(b);
    }

    // Ratakan menjadi baris (judul tujuan = [String], bus = [BusWithDistance])
    // lalu bangun memakai [ListView.builder] agar item di luar layar tidak ikut
    // dibangun — penting supaya geseran antar tab tetap mulus saat bus banyak.
    final rows = <Object>[];
    groups.forEach((dest, list) {
      rows.add(dest);
      rows.addAll(list);
    });

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 2, bottom: 24),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is String) {
          return _DestinationHeader(destination: row, corridor: corridor);
        }
        final b = row as BusWithDistance;
        return BusTile(
          item: b,
          showDestination: false,
          onTap: () => showBusTimeline(context, b),
        );
      },
    );
  }
}

/// Judul bagian tujuan pada daftar bus (mis. "Tujuan Pusat Pemerintahan ...").
///
/// Dibuat menonjol berupa pita (band) berlatar aksen koridor dengan ikon
/// terisi + teks tebal berwarna, supaya pengguna langsung mengenali kelompok
/// tujuan yang sedang dilihat saat menggulir. Jarak atasnya sama untuk semua
/// kelompok dan untuk kartu "Info Koridor" (kartu 4 + padding daftar 2 + 10 =
/// tile bawah 6 + 10) sehingga spasi tetap konsisten.
class _DestinationHeader extends StatelessWidget {
  final String destination;
  final String corridor;

  const _DestinationHeader({required this.destination, required this.corridor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = corridorAccent(corridor, theme);
    final band = corridorSurfaceTint(
      corridor,
      theme,
      base: theme.colorScheme.surface,
      opacity: 0.18,
    );
    final fg = corridorOnBackground(corridor, band);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: band,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: Icon(Icons.navigation, size: 15, color: onColor(accent)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context).destinationHeader(destination),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris pemilih koridor: chip "Semua" diikuti ikon bulat berwarna masing-masing
/// koridor. Terhubung ke [TabController] yang sama dengan [TabBarView], jadi
/// ikon bisa diketuk untuk pindah halaman dan sorotannya ikut bergerak ketika
/// pengguna menggeser layar.
class _CorridorTabs extends StatelessWidget {
  final TabController controller;
  final List<String> corridors;

  const _CorridorTabs({required this.controller, required this.corridors});

  void _goTo(int index) {
    if (controller.index == index) return;
    controller.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Sorotan tidak lagi menunggu tab benar-benar berganti (index hanya berubah
    // setelah geseran selesai = terasa telat). Posisi tab dibaca kontinu dari
    // [TabController.animation] yang ikut ter-update pada setiap frame geseran,
    // sehingga ikon menyorot mulus mengikuti jari.
    final animation =
        controller.animation ?? const AlwaysStoppedAnimation<double>(0);

    // Hitung warna tiap koridor SEKALI di sini, bukan tiap frame geseran:
    // perhitungan kontras warna relatif mahal dan hasilnya tetap selama geseran.
    final palettes = [
      for (final corridor in corridors) CorridorPalette.of(corridor, theme),
    ];

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          // Tiap ikon dibungkus [AnimatedBuilder] sendiri supaya hanya ikon itu
          // yang dibangun ulang tiap frame geseran, bukan seluruh baris.
          AnimatedBuilder(
            animation: animation,
            builder: (context, _) => _chip(
              label: l10n.filterAll,
              selFactor: (1.0 - animation.value).clamp(0.0, 1.0),
              onTap: () => _goTo(0),
            ),
          ),
          for (var i = 0; i < corridors.length; i++)
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) => CorridorIconButton(
                corridor: corridors[i],
                palette: palettes[i],
                selFactor:
                    (1.0 - (animation.value - (i + 1)).abs()).clamp(0.0, 1.0),
                onTap: () => _goTo(i + 1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required double selFactor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selFactor > 0.5,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ConnectionStatus? status;

  const _EmptyState({super.key, this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOutsideHours = status == ConnectionStatus.outsideHours;
    final message = isOutsideHours
        ? l10n.outsideHoursMessage
        : l10n.noBusesMessage;
    final icon =
        isOutsideHours ? Icons.schedule : Icons.directions_bus_outlined;

    return EmptyStateView(
      icon: icon,
      message: message,
      scrollable: true,
    );
  }
}

/// Tampilan penuh saat layanan sedang tidak melayani penumpang (di luar jam
/// operasional). Daftar bus sengaja tidak ditampilkan; pengguna hanya melihat
/// informasi jam operasional.
class _OutsideHoursView extends StatelessWidget {
  const _OutsideHoursView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.nightlight_round,
              size: 64,
              color: const Color(0xFF7B1FA2).withOpacity(0.8),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.outsideHoursTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.outsideHoursMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol ikon di AppBar. Setiap kali diklik, ikonnya berputar **satu kali**
/// sebagai umpan balik, lalu berhenti (tidak berputar terus-menerus).
class _SpinIconButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _SpinIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_SpinIconButton> createState() => _SpinIconButtonState();
}

class _SpinIconButtonState extends State<_SpinIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addStatusListener(_onSpinStatus);
  }

  void _onSpinStatus(AnimationStatus status) {
    // Kembalikan ke posisi awal setelah satu putaran agar idle lagi
    // (0 dan 1 putaran identik, jadi tidak terlihat melompat).
    if (status == AnimationStatus.completed) {
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _handle() {
    // Berputar sekali tiap klik — tidak terus-menerus.
    if (!_spin.isAnimating) {
      _spin.forward(from: 0);
    }
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: _handle,
      icon: RotationTransition(
        turns: _spin,
        child: Icon(widget.icon),
      ),
    );
  }
}
