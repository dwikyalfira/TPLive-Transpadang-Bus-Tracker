import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/follow_service.dart';
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
import 'widgets/format.dart';
import 'widgets/halte_timeline_sheet.dart';
import 'widgets/live_status_pill.dart';

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
  }

  /// Memulihkan indikator "mengikuti" bila foreground service masih aktif
  /// (mis. setelah aplikasi dibuka ulang).
  Future<void> _restoreFollow() async {
    final followed = await FollowService.getFollowed();
    if (!mounted || followed == null) return;
    ref.read(followedBusProvider.notifier).state =
        busFollowKey(followed.corridor, followed.busNumber);
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
    // Di luar jam operasional (05:00-20:00 WIB) dihitung oleh provider yang
    // diperbarui tiap menit sehingga penanda ikut berubah tanpa membuka ulang
    // aplikasi. Saat true, AppBar tetap tampil (penanda status ungu), namun
    // daftar bus disembunyikan dan diganti info jam operasional.
    final isOutsideHours =
        ref.watch(outsideHoursProvider).valueOrNull ?? false;
    final status = ref.watch(connectionStatusProvider).valueOrNull;
    final locationAsync = ref.watch(userLocationProvider);
    final nearby = ref.watch(nearbyBusesProvider);
    final corridors = ref.watch(availableCorridorsProvider);

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
            LiveStatusPill(status: status, onTap: () {}),
          ],
        ),
        actions: [
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
      body: isOutsideHours
          ? const _OutsideHoursView()
          : locationAsync.hasError
              ? _LocationErrorState(
                  message: locationAsync.error.toString(),
                  onRetry: () => ref.invalidate(userLocationProvider),
                )
              : locationAsync.isLoading || !locationAsync.hasValue
                  ? _LoadingState(message: l10n.gettingLocation)
                  : _BusListView(
                      status: status,
                      nearby: nearby,
                      corridors: corridors,
                      onSearchTap: () => _openTripSearch(context),
                      onRefresh: _refresh,
                    ),
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

  /// Transisi halus menuju layar Pengaturan: memudar masuk sambil meluncur
  /// naik tipis (fade-through), selaras dengan transisi pencarian perjalanan.
  Route<void> _settingsRoute() {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SettingsScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _openTripSearch(BuildContext context) {
    Navigator.of(context).push(_tripSearchRoute());
  }

  /// Transisi halus menuju layar "Cari tujuan": fade-through — halaman baru
  /// memudar masuk sambil meluncur naik sedikit (efek search → hasil).
  Route<void> _tripSearchRoute() {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const TripScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
  final VoidCallback onSearchTap;
  final Future<void> Function() onRefresh;

  const _BusListView({
    required this.status,
    required this.nearby,
    required this.corridors,
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

    final content = buses.isEmpty
        ? _EmptyState(key: key, status: widget.status)
        : corridor == null
            ? _FlatBusList(key: key, buses: buses)
            : _GroupedBusList(key: key, buses: buses);

    return Column(
      children: [
        CorridorInfoHeader(corridor: corridor),
        Expanded(
          child: RefreshIndicator(
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
    final groups = <String, List<BusWithDistance>>{};
    for (final b in buses) {
      final dest = b.destinationLabel ?? l10n.unknown;
      groups.putIfAbsent(dest, () => <BusWithDistance>[]).add(b);
    }

    final children = <Widget>[];
    groups.forEach((dest, list) {
      children.add(_DestinationHeader(destination: dest));
      for (final b in list) {
        children.add(BusTile(
          item: b,
          showDestination: false,
          onTap: () => showBusTimeline(context, b),
        ));
      }
    });

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: children,
    );
  }
}

/// Judul bagian tujuan pada daftar bus (mis. "Tujuan Pusat Pemerintahan ...").
class _DestinationHeader extends StatelessWidget {
  final String destination;

  const _DestinationHeader({required this.destination});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 2),
      child: Row(
        children: [
          Icon(Icons.navigation, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              AppLocalizations.of(context).destinationHeader(destination),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
    // Sorotan tidak lagi menunggu tab benar-benar berganti (index hanya berubah
    // setelah geseran selesai = terasa telat). Sebagai gantinya, posisi tab
    // dibaca kontinu dari [TabController.animation] yang ikut ter-update pada
    // setiap frame geseran, sehingga ikon menyorot mulus mengikuti jari.
    final animation =
        controller.animation ?? const AlwaysStoppedAnimation<double>(0);
    return SizedBox(
      height: 52,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final position = controller.animation?.value ?? controller.index.toDouble();
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _chip(
                context,
                label: AppLocalizations.of(context).filterAll,
                selFactor: (1.0 - position).clamp(0.0, 1.0),
                onTap: () => _goTo(0),
              ),
              for (var i = 0; i < corridors.length; i++)
                _corridorButton(
                  context,
                  corridor: corridors[i],
                  selFactor: (1.0 - (position - (i + 1)).abs()).clamp(0.0, 1.0),
                  onTap: () => _goTo(i + 1),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
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

  Widget _corridorButton(
    BuildContext context, {
    required String corridor,
    required double selFactor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final base = corridorAccent(corridor, theme);
    final unselectedBg =
        Color.alphaBlend(base.withOpacity(0.35), theme.colorScheme.surface);
    final t = selFactor.clamp(0.0, 1.0);
    final bg = Color.lerp(base.withOpacity(0.35), base, t)!;
    final fg = Color.lerp(
      corridorOnBackground(corridor, unselectedBg),
      onCorridorColor(corridor),
      t,
    )!;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Transform.scale(
          scale: 1 + 0.06 * t,
          child: AnimatedContainer(
            // Sorotan sudah dipandu tiap frame lewat [AnimatedBuilder]; durasi
            // nol menghindari penundaan ganda.
            duration: Duration.zero,
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(t),
                width: 2 * t,
              ),
            ),
            child: Text(
              corridor,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
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

    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
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

class _LoadingState extends StatelessWidget {
  final String message;

  const _LoadingState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
}

class _LocationErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LocationErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).retry),
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
