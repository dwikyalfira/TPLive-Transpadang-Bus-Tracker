import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/bus_model.dart';
import '../../domain/bus_with_distance.dart';
import '../../domain/geo_utils.dart' as geo;
import '../../domain/halte_tracker.dart';
import '../../../trip/domain/trip_planner.dart';
import '../../../trip/presentation/trip_providers.dart';
import '../providers.dart';
import 'follow_bus_button.dart';
import 'format.dart';

/// Menentukan rentang halte naik→turun pada [progress] dari rencana
/// perjalanan aktif ([plan]). Segmen hanya berlaku bila koridor dan arah
/// perjalanan yang direncanakan cocok dengan bus yang sedang ditampilkan
/// (akurasi [HalteProgress.steps] sama dengan urutan halte arah koridor).
/// `null` bila tidak ada rencana/cocok — timeline tampil penuh seperti biasa.
///
/// Berbeda dari mencocokkan endpoint "Dari"/"Ke", pendekatan ini juga bekerja
/// saat asal berupa lokasi GPS (perencana otomatis memilih halte terdekat).
({int origin, int destination})? _segmentFromPlan(
  TripPlan? plan,
  Bus bus,
  HalteProgress progress,
) {
  if (plan == null) return null;
  for (final option in plan.options) {
    for (final leg in option.legs) {
      if (leg.corridor != bus.corridor) continue;
      if (leg.arahKey != progress.arahKey) continue;
      return (origin: leg.boardIndex, destination: leg.alightIndex);
    }
  }
  return null;
}

/// Menampilkan timeline halte sebuah bus dalam bottom sheet.
///
/// Data bus diambil ulang secara live dari [nearbyBusesProvider] sehingga
/// kartu & timeline ikut ter-refresh saat posisi bus berubah.
///
/// Selama sheet terbuka, [pinnedDetailOpenProvider] bernilai benar sehingga
/// kartu melayang bus yang di-pin hanya ditampilkan dalam versi kecil (mini).
/// Saat sheet ditutup, penanda dibersihkan dan kartu tetap beristirahat mini.
Future<void> showBusTimeline(BuildContext context, BusWithDistance item) {
  final container = ProviderScope.containerOf(context, listen: false);
  container
    ..read(pinnedDetailOpenProvider.notifier).state = true
    ..read(pinnedCardCollapsedProvider.notifier).state = true;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => HalteTimelineSheet(item: item),
  ).whenComplete(() {
    container
      ..read(pinnedCardCollapsedProvider.notifier).state = true
      ..read(pinnedDetailOpenProvider.notifier).state = false;
  });
}

class HalteTimelineSheet extends ConsumerWidget {
  final BusWithDistance item;

  const HalteTimelineSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datasetAsync = ref.watch(halteDatasetProvider);
    final live = _resolveLive(ref.watch(nearbyBusesProvider));

    // Tinggi tetap: sheet langsung tampil 90% layar & tidak perlu di-scroll
    // untuk membukanya. Hanya timeline di dalamnya yang dapat di-scroll.
    // Kurangi tinggi drag handle (kMinInteractiveDimension) karena modal
    // menambahkan padding tersebut di atas konten.
    final height =
        MediaQuery.sizeOf(context).height * 0.9 - kMinInteractiveDimension;

    return SizedBox(
      height: height,
      child: datasetAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              AppLocalizations.of(context).halteDataLoadFailed('$e'),
            ),
          ),
        ),
        data: (dataset) {
          final progress = HalteTracker.track(
            live.bus,
            dataset,
            estimatedHeading: live.resolvedHeading,
          );
          if (progress == null) {
            return _Unavailable(bus: live.bus);
          }

          // Bila rencana perjalanan aktif (asal & turun ditetapkan), sorot
          // segmen naik→turun; halte di luar segmen diredupkan.
          final plan = ref.watch(tripPlanProvider);
          final segment = _segmentFromPlan(plan, live.bus, progress);

          return _Timeline(
            bus: live.bus,
            progress: progress,
            segment: segment,
          );
        },
      ),
    );
  }

  /// Mengambil data bus terbaru yang cocok; fallback ke data awal.
  BusWithDistance _resolveLive(List<BusWithDistance> list) {
    for (final b in list) {
      if (b.bus.corridor == item.bus.corridor &&
          b.bus.number == item.bus.number) {
        return b;
      }
    }
    return item;
  }
}

class _Timeline extends StatefulWidget {
  final Bus bus;
  final HalteProgress progress;

  /// Rentang halte naik→turun bila asal & turun sudah ditetapkan (lihat
  /// [_resolveSegment]); `null` = tampilkan seluruh lintasan normal.
  final ({int origin, int destination})? segment;

  const _Timeline({
    required this.bus,
    required this.progress,
    this.segment,
  });

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  /// Kunci untuk baris posisi bus saat ini agar bisa dipusatkan.
  final GlobalKey _focusKey = GlobalKey();
  final ScrollController _listController = ScrollController();
  int _focusedIndex = -1;
  bool _didInitialCenter = false;

  /// Tinggi tiap baris halte (padding vertikal 6+6 + konten 40) — dipakai
  /// untuk menghitung posisi penanda bus di rel antar halte.
  static const double _rowHeight = 52;

  /// Offset scroll timeline saat ini (untuk menggeser penanda bus bersama
  /// konten saat ListView di-scroll).
  double _scrollOffset = 0;

  int get _centerIndex =>
      widget.progress.currentIndex ?? widget.progress.nextIndex;

  @override
  void initState() {
    super.initState();
    _listController.addListener(_onListScroll);
  }

  @override
  void dispose() {
    _listController
      ..removeListener(_onListScroll)
      ..dispose();
    super.dispose();
  }

  void _onListScroll() {
    final offset = _listController.hasClients ? _listController.offset : 0.0;
    if ((offset - _scrollOffset).abs() > 0.5) {
      setState(() => _scrollOffset = offset);
    }
  }

  void _scheduleCenter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _focusKey.currentContext;
      if (ctx == null) return;
      final first = !_didInitialCenter;
      _didInitialCenter = true;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: first ? Duration.zero : const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  /// Fraksi [0,1] posisi bus di antara halte saat ini → halte berikutnya
  /// (0 = tepat di halte saat ini, 1 = tepat di halte berikutnya).
  double _busGapFraction() {
    final steps = widget.progress.steps;
    if (steps.isEmpty) return 0;
    final cur = widget.progress.currentIndex;
    final nxt = widget.progress.nextIndex;
    if (cur == null) return 0;
    if (nxt >= steps.length) return 1;
    final (_, t) = geo.projectOnSegment(
      widget.bus.position,
      steps[cur].halte.pos,
      steps[nxt].halte.pos,
    );
    return t.clamp(0.0, 1.0);
  }

  /// Posisi vertikal tengah penanda bus relatif Stack di atas viewport list.
  double _busCenterY() {
    final cur = widget.progress.currentIndex;
    final base = (cur ?? 0).toDouble();
    return (base + 0.5 + _busGapFraction()) * _rowHeight - _scrollOffset;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bus = widget.bus;
    final progress = widget.progress;
    final seg = widget.segment;
    final next = progress.nextStep;
    final current = progress.currentStep;
    final etaNext = next == null
        ? null
        : geo.estimateEtaMinutes(next.distanceKm, bus.speedKmh);

    final idx = _centerIndex;
    if (idx != _focusedIndex) {
      _focusedIndex = idx;
      _scheduleCenter();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bagian atas (static, tidak ikut ter-scroll).
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              bus: bus,
              origin: progress.origin,
              destination: progress.destination,
              fallback: progress.direction.label,
              follow: FollowPayload(
                originLabel: progress.originLabel,
                destinationLabel: progress.destinationLabel,
                route: bus.route,
                directionKey: progress.arahKey,
                haltes: progress.direction.halte,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: _HighlightCard(
                current: current,
                next: next,
                etaMinutes: etaNext,
                speedKmh: bus.speedKmh,
                accent: corridorAccent(bus.corridor, theme),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Ringkasan jumlah halte (diletakkan di luar area scroll supaya
        // koordinat penanda bus di rel halte tetap presisi terhadap baris).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            _countLabel(progress, seg, AppLocalizations.of(context)),
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        // Timeline halte (scrollable). Penanda posisi bus digambar di atas
        // viewport, diposisikan di rel antar halte sesuai posisi aktual bus.
        Expanded(
          child: Stack(
            children: [
              ListView(
                controller: _listController,
                cacheExtent: 6000,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  for (var i = 0; i < progress.steps.length; i++)
                    _HalteRow(
                      key: i == idx ? _focusKey : null,
                      step: progress.steps[i],
                      corridorColor: corridorAccent(bus.corridor, theme),
                      isFirst: i == 0,
                      isLast: i == progress.steps.length - 1,
                      dimmed: seg != null &&
                          (i < math.min(seg.origin, seg.destination) ||
                              i > math.max(seg.origin, seg.destination)),
                      isOrigin: seg != null && i == seg.origin,
                      isDestination: seg != null && i == seg.destination,
                    ),
                ],
              ),
              if (progress.steps.isNotEmpty)
                Positioned(
                  left: 23,
                  top: _busCenterY() - 13,
child: _BusPositionMarker(
              color: corridorAccent(bus.corridor, theme),
            ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Label jumlah halte; bila segmen naik→turun aktif, cantumkan nama asal &
  /// turun beserta jangkauannya.
  String _countLabel(
    HalteProgress progress,
    ({int origin, int destination})? seg,
    AppLocalizations l10n,
  ) {
    if (seg == null) return l10n.countHalte(progress.steps.length);
    final lo = math.min(seg.origin, seg.destination);
    final hi = math.max(seg.origin, seg.destination);
    final n = hi - lo + 1;
    return l10n.countHalteRange(
      progress.steps[seg.origin].halte.nama,
      progress.steps[seg.destination].halte.nama,
      n,
      progress.steps.length,
    );
  }
}

/// Data yang dibutuhkan untuk fitur "ikuti bus" (diteruskan ke tombol header).
class _Header extends StatelessWidget {
  final Bus bus;
  final String? origin;
  final String? destination;
  final String fallback;
  final FollowPayload follow;

  const _Header({
    required this.bus,
    required this.origin,
    required this.destination,
    required this.fallback,
    required this.follow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = corridorAccent(bus.corridor, theme);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Text(
              bus.corridor.isEmpty ? '?' : bus.corridor,
              style: TextStyle(
                color: onColor(color),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).busLabel(bus.number),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                _subtitle(theme),
              ],
            ),
          ),
          const SizedBox(width: 4),
          FollowBusButton(bus: bus, payload: follow, activeColor: color),
        ],
      ),
    );
  }

  Widget _subtitle(ThemeData theme) {
    // Tampilkan kedua terminus rute (asal ⇄ tujuan). Tujuan yang sedang
    // ditempuh bus dicetak TEBAL agar langsung terlihat, mis.
    // "RTH Imam Bonjol  ⇄  Pusat Pemerintahan Balai Kota Padang".
    final o = origin?.trim();
    final d = destination?.trim();
    if (o == null || o.isEmpty || d == null || d.isEmpty) {
      return Text(
        bus.route.trim().isNotEmpty ? bus.route : fallback,
        style: theme.textTheme.bodyMedium,
      );
    }
    final arrowStyle = theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.bold,
    );
    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodyMedium,
        children: [
          TextSpan(text: o),
          TextSpan(text: '  \u21C4  ', style: arrowStyle),
          TextSpan(
            text: d,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: corridorAccent(bus.corridor, theme),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final HalteStep? current;
  final HalteStep? next;
  final int? etaMinutes;

  /// Kecepatan bus saat ini (km/j, dari field `speed` API) bila tersedia.
  final double? speedKmh;
  final Color accent;

  const _HighlightCard({
    required this.current,
    required this.next,
    required this.etaMinutes,
    required this.speedKmh,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Baris atas: info "Sedang di" + lingkaran kecepatan (kecil) di
          // kanan. Lingkaran tidak menyempitkan baris halte berikutnya, jadi
          // jarak & estimasi tetap rata ke tepi kanan kartu.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (current != null) ...[
                      Row(
                        children: [
                          Icon(Icons.radio_button_checked,
                              size: 16, color: color),
                          const SizedBox(width: 6),
                          Text(l10n.currentAt,
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                      Text(
                        current!.halte.nama,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              if (current != null) const SizedBox(width: 8),
              // Kecepatan real-time dalam lingkaran ala speedometer
              // (tanpa label).
              if (speedKmh != null && speedKmh! > 0)
                _SpeedDial(speedKmh: speedKmh!, color: color),
            ],
          ),
          if (current != null) const SizedBox(height: 8),
          Row(
            children: [
              Transform.rotate(
                angle: math.pi,
                child: Icon(Icons.navigation, size: 16, color: color),
              ),
              const SizedBox(width: 6),
              Text(l10n.nextHalte,
                  style: theme.textTheme.labelMedium?.copyWith(color: color)),
            ],
          ),
          if (next != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    next!.halte.nama,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatDistance(next!.distanceKm),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
                if (etaMinutes != null)
                  Text(
                    l10n.etaSuffix(etaMinutes!),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
              ],
            )
          else
            Text(l10n.unknown,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Lingkaran kecepatan ala speedometer: angka besar + satuan kecil "km/j".
/// Terisi warna koridor supaya mencolok dan langsung terbaca real-time.
class _SpeedDial extends StatelessWidget {
  final double speedKmh;
  final Color color;

  const _SpeedDial({required this.speedKmh, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor2 = onColor(color);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${speedKmh.round()}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: onColor2,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          Text(
            AppLocalizations.of(context).speedUnit,
            style: theme.textTheme.labelSmall?.copyWith(
              color: onColor2,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _HalteRow extends StatelessWidget {
  final HalteStep step;
  final Color corridorColor;
  final bool isFirst;
  final bool isLast;

  /// Bila benar (halte di luar segmen naik→turun), baris diredupkan.
  final bool dimmed;

  /// Halte naik (titik asal pada segmen) — ditandai badge "Naik".
  final bool isOrigin;

  /// Halte turun (titik tujuan pada segmen) — ditandai badge "Turun".
  final bool isDestination;

  const _HalteRow({
    super.key,
    required this.step,
    required this.corridorColor,
    this.isFirst = false,
    this.isLast = false,
    this.dimmed = false,
    this.isOrigin = false,
    this.isDestination = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isNext = step.mark == HalteMark.next;
    final isCurrent = step.mark == HalteMark.current;
    final isPassed = step.mark == HalteMark.passed;
    final isEdge = isFirst || isLast;

    // Baris di luar segmen naik→turun diredupkan agar fokus pada perjalanan
    // pengguna; konteks arah tetap terbaca dari rel.
    final dimColor = theme.colorScheme.onSurfaceVariant.withOpacity(0.35);
    final textColor = theme.colorScheme.onSurfaceVariant.withOpacity(0.5);

    final IconData icon;
    final Color color;
    if (isNext) {
      icon = Icons.navigation;
      color = dimmed ? dimColor : corridorColor;
    } else if (isCurrent) {
      icon = Icons.radio_button_checked;
      color = dimmed ? dimColor : corridorColor;
    } else if (isLast) {
      // Penanda terminus di ujung akhir lintasan.
      icon = Icons.flag;
      color = dimmed
          ? dimColor
          : isPassed
              ? theme.colorScheme.onSurfaceVariant.withOpacity(0.6)
              : corridorColor;
    } else if (isPassed) {
      icon = Icons.check_circle;
      color = dimmed ? dimColor : theme.colorScheme.onSurfaceVariant.withOpacity(0.6);
    } else {
      icon = Icons.circle_outlined;
      color = dimmed ? dimColor : theme.colorScheme.onSurfaceVariant.withOpacity(0.5);
    }

    final emphasize = isNext || isCurrent || isEdge;
    final textStyle = dimmed
        ? theme.textTheme.bodyLarge?.copyWith(color: textColor)
        : emphasize
            ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)
            : theme.textTheme.bodyLarge?.copyWith(
                color: isPassed ? theme.colorScheme.onSurfaceVariant : null,
              );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Stack(
        children: [
          // Garis rel waktu di belakang ikon (row ini mentah/ringan, tanpa
          // IntrinsicHeight agar scroll tetap halus). Untuk halte TERAKHIR
          // garis berhenti tepat di tengah penanda, tidak menembus titik akhir;
          // untuk halte PERTAMA garis mulai dari tengah penanda (tidak lewat).
          Positioned(
            left: 20 - 1,
            top: isFirst ? 20 : 0,
            height: isLast ? 20 : null,
            bottom: isLast ? null : 0,
            child: Container(
              width: 2,
              color: isPassed
                  ? theme.colorScheme.onSurfaceVariant.withOpacity(0.25)
                  : theme.dividerColor,
            ),
          ),
          // Tinggi konten dibuat tetap 40 (total baris = 6+6+40) supaya
          // posisi penanda bus di rel antar halte dapat dihitung pasti.
          SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: isNext
                          ? Transform.rotate(
                              angle: math.pi,
                              child: Icon(icon, size: 20, color: color),
                            )
                          : Icon(icon, size: 20, color: color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          step.halte.nama,
                          style: textStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOrigin)
                        _EdgeBadge(
                          label: l10n.badgeBoard,
                          icon: Icons.lens,
                          color: corridorColor,
                          filled: true,
                        )
                      else if (isFirst)
                        _EdgeBadge(
                          label: l10n.badgeStart,
                          icon: Icons.trip_origin,
                          color: corridorColor,
                        ),
                      if (isDestination)
                        _EdgeBadge(
                          label: l10n.badgeAlight,
                          icon: Icons.place,
                          color: corridorColor,
                          filled: true,
                        )
                      else if (isLast)
                        _EdgeBadge(
                          label: l10n.badgeEnd,
                          icon: Icons.flag,
                          color: corridorColor,
                        ),
                      if (isNext || isCurrent)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            formatDistance(step.distanceKm),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: corridorColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Penanda posisi bus saat ini: ikon bus di dalam lingkaran putih berbingkai
/// warna koridor (tegak/lurus). Berbeda dari penanda halte berikutnya (panah)
/// sehingga posisi bus langsung terlihat.
class _BusPositionMarker extends StatelessWidget {
  final Color color;

  const _BusPositionMarker({required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(Icons.directions_bus, size: 16, color: color),
    );
  }
}

class _EdgeBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  /// Bila benar, pill terisi penuh warna koridor (untuk penanda Naik/Turun
  /// pengguna) supaya jelas berbeda dari penanda terminus Awal/Akhir yang
  /// transparan (samar).
  final bool filled;

  const _EdgeBadge({
    required this.label,
    required this.icon,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor2 = onColor(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: filled ? color : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: filled ? onColor2 : color),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: filled ? onColor2 : color,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  final Bus bus;

  const _Unavailable({required this.bus});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.route_outlined, size: 56, color: Colors.grey),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            AppLocalizations.of(context).halteUnavailable(bus.corridor),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
