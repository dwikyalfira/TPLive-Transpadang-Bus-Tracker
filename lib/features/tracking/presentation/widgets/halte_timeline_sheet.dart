import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/bus_model.dart';
import '../../domain/bus_with_distance.dart';
import '../../domain/geo_utils.dart' as geo;
import '../../domain/halte_tracker.dart';
import '../../../trip/domain/trip_planner.dart';
import '../../../trip/presentation/trip_providers.dart';
import '../providers.dart';
import 'corridor_badge.dart';
import 'follow_bus_button.dart';
import 'format.dart';
import 'speed_dial.dart';

/// Tinggi maksimum sheet detail bus sebagai fraksi tinggi layar. Dipakai oleh
/// [DraggableScrollableSheet] (ukuran awal & maksimum) dan [_DismissDragRegion]
/// agar konsisten.
const double _busSheetMaxSize = 0.9;

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
    // Drag & handle ditangani sendiri oleh [DraggableScrollableSheet] agar
    // tidak bentrok dengan gestur modal (menarik timeline turun menutup sheet).
    showDragHandle: false,
    enableDrag: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    // Sudut atas membulat (radius dari tema, selaras Info Koridor & M3).
    shape: const RoundedRectangleBorder(borderRadius: AppShape.topExtraLarge),
    clipBehavior: Clip.antiAlias,
    builder: (_) => HalteTimelineSheet(item: item),
  ).whenComplete(() {
    container
      ..read(pinnedCardCollapsedProvider.notifier).state = true
      ..read(pinnedDetailOpenProvider.notifier).state = false;
  });
}

class HalteTimelineSheet extends ConsumerStatefulWidget {
  final BusWithDistance item;

  const HalteTimelineSheet({super.key, required this.item});

  @override
  ConsumerState<HalteTimelineSheet> createState() =>
      _HalteTimelineSheetState();
}

class _HalteTimelineSheetState extends ConsumerState<HalteTimelineSheet> {
  /// Controller sheet dipakai agar header yang dipin (di luar daftar scroll)
  /// tetap dapat ditarik turun untuk menutup sheet lewat [_DismissDragRegion].
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final datasetAsync = ref.watch(halteDatasetProvider);
    final live = _resolveLive(ref.watch(nearbyBusesProvider));

    // Sheet berjenjang: terbuka 90% layar & tidak bisa diperbesar. Header
    // (handle + kartu) dipin di atas; HANYA daftar halte yang bergerak. Menarik
    // turun dari area mana pun (header maupun daftar) menutup sheet.
    return DraggableScrollableSheet(
      controller: _sheetController,
      expand: false,
      initialChildSize: _busSheetMaxSize,
      minChildSize: 0.0,
      maxChildSize: _busSheetMaxSize,
      builder: (context, scrollController) {
        return datasetAsync.when(
          loading: () => _sheetList(
            scrollController,
            const [
              SizedBox(height: 160),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (e, _) => _sheetList(
            scrollController,
            [
              const SizedBox(height: 160),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    AppLocalizations.of(context).halteDataLoadFailed('$e'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          data: (dataset) {
            final progress = HalteTracker.track(
              live.bus,
              dataset,
              estimatedHeading: live.resolvedHeading,
            );
            if (progress == null) {
              return _sheetList(scrollController, [_Unavailable(bus: live.bus)]);
            }

            // Bila rencana perjalanan aktif (asal & turun ditetapkan), sorot
            // segmen naik→turun; halte di luar segmen diredupkan.
            final plan = ref.watch(tripPlanProvider);
            final segment = _segmentFromPlan(plan, live.bus, progress);

            return _Timeline(
              bus: live.bus,
              progress: progress,
              segment: segment,
              scrollController: scrollController,
              sheetController: _sheetController,
            );
          },
        );
      },
    );
  }

  /// Daftar standar sheet: bilah handle di atas lalu [children]. Dipakai pada
  /// state loading/error/halte-tak-tersedia agar sheet tetap dapat ditutup
  /// dengan menarik turun—dan tidak meluber saat sheet mengecil (ter-clip).
  Widget _sheetList(ScrollController controller, List<Widget> children) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 24),
      children: [const _SheetDragHandle(), ...children],
    );
  }

  /// Mengambil data bus terbaru yang cocok; fallback ke data awal.
  BusWithDistance _resolveLive(List<BusWithDistance> list) {
    for (final b in list) {
      if (b.bus.corridor == widget.item.bus.corridor &&
          b.bus.number == widget.item.bus.number) {
        return b;
      }
    }
    return widget.item;
  }
}

/// Membungkus area sheet yang **tidak** dapat di-scroll agar dapat ditarik
/// turun untuk mengubah tinggi sheet—dan menutupnya saat mencapai minimum.
///
/// Dipakai pada header yang dipin di atas daftar halte.
class _DismissDragRegion extends StatefulWidget {
  final DraggableScrollableController controller;

  final Widget child;

  const _DismissDragRegion({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<_DismissDragRegion> createState() => _DismissDragRegionState();
}

class _DismissDragRegionState extends State<_DismissDragRegion> {
  double _startSize = 0;
  double _accumulatedDy = 0;

  void _onStart(DragStartDetails _) {
    _accumulatedDy = 0;
    _startSize = widget.controller.isAttached
        ? widget.controller.size
        : _busSheetMaxSize;
  }

  void _onUpdate(DragUpdateDetails d) {
    if (!widget.controller.isAttached) return;
    _accumulatedDy += d.delta.dy;
    final target =
        (_startSize - widget.controller.pixelsToSize(_accumulatedDy))
            .clamp(0.0, _busSheetMaxSize);
    widget.controller.jumpTo(target);
  }

  void _onEnd(DragEndDetails d) {
    if (!widget.controller.isAttached) return;
    // Hormati kecepatan (fling) jari: swipe ke bawah yang cepat menutup sheet
    // tanpa harus menariknya lebih dulu melewati separuh tinggi. Tanpa ini,
    // swipe pendek-cepat akan memantul kembali sehingga terasa tidak menempel
    // ke jari ("tidak seamless").
    final flung = d.velocity.pixelsPerSecond.dy > 280;
    final closing = flung || widget.controller.size < _busSheetMaxSize * 0.5;
    widget.controller.animateTo(
      closing ? 0.0 : _busSheetMaxSize,
      duration: closing ? AppMotion.short4 : AppMotion.medium4,
      curve: closing
          ? AppMotion.emphasizedAccelerate
          : AppMotion.emphasizedDecelerate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _onStart,
      onVerticalDragUpdate: _onUpdate,
      onVerticalDragEnd: _onEnd,
      child: widget.child,
    );
  }
}

/// Bilah pegangan (visual) di bagian atas sheet detail bus.
///
/// Berada di dalam header yang dipin; menarik turun dari sini mengecilkan dan
/// menutup sheet lewat [_DismissDragRegion].
class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _Timeline extends StatefulWidget {
  final Bus bus;
  final HalteProgress progress;

  /// Rentang halte naik→turun bila asal & turun sudah ditetapkan (lihat
  /// [_resolveSegment]); `null` = tampilkan seluruh lintasan normal.
  final ({int origin, int destination})? segment;

  /// Controller dari [DraggableScrollableSheet]; ditempel ke daftar halte
  /// sehingga menarik turun saat sudah di puncak mengecilkan & menutup sheet.
  final ScrollController scrollController;

  /// Controller sheet yang sama; dipakai [_DismissDragRegion] pada header yang
  /// dipin agar menarik turun header pun menutup sheet.
  final DraggableScrollableController sheetController;

  const _Timeline({
    required this.bus,
    required this.progress,
    this.segment,
    required this.scrollController,
    required this.sheetController,
  });

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  /// Kunci untuk baris posisi bus saat ini agar bisa dipusatkan.
  final GlobalKey _focusKey = GlobalKey();
  int _focusedIndex = -1;
  bool _didInitialCenter = false;

  /// Tinggi tiap baris halte (padding vertikal 6+6 + konten 40) — dipakai
  /// untuk menghitung posisi penanda bus di rel antar halte.
  static const double _rowHeight = 52;

  /// Offset scroll timeline saat ini (untuk menggeser penanda bus bersama
  /// konten saat ListView di-scroll). Diambil dari notifikasi scroll ListView
  /// yang menempel pada controller sheet. Dipakai lewat [ValueNotifier] agar
  /// hanya penanda bus yang di-rebuild tiap frame — bukan seluruh daftar halte
  /// (menjaga scroll tetap ringan).
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);

  /// Kunci untuk blok header (bilah handle + kartu + rincian) yang dipin di
  /// atas daftar. Tingginya diukur untuk dua hal: menyamakan padding-atas daftar
  /// halte (agar baris pertama mulai tepat di bawah header) dan menghitung
  /// posisi penanda bus pada koordinat viewport.
  final GlobalKey _headerKey = GlobalKey();

  /// Tinggi blok header yang telah diukur (offset baris halte pertama).
  double _headerExtent = 0;

  int get _centerIndex =>
      widget.progress.currentIndex ?? widget.progress.nextIndex;

  void _onScrollNotification(ScrollNotification n) {
    final pixels = n.metrics.pixels;
    if ((pixels - _scrollOffset.value).abs() > 0.5) {
      _scrollOffset.value = pixels;
    }
  }

  /// Mengukur tinggi header setelah layout; memperbarui penanda bus bila
  /// berubah (mis. label halte membungkus ke baris kedua).
  void _measureHeader() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ro = _headerKey.currentContext?.findRenderObject();
      if (ro is RenderBox && ro.hasSize) {
        final h = ro.size.height;
        if ((h - _headerExtent).abs() > 0.5) {
          setState(() => _headerExtent = h);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollOffset.dispose();
    super.dispose();
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

    // Posisi dasar penanda bus relatif terhadap baris halte pertama (sebelum
    // dikurangi offset scroll & tinggi header). Dihitung sekali per build—bukan
    // tiap frame—karena tidak bergantung pada scroll.
    final markerBaseY =
        ((progress.currentIndex ?? 0) + 0.5 + _busGapFraction()) * _rowHeight;

    _measureHeader();

    // Header (handle + kartu) dipin di atas lewat Stack sehingga TIDAK ikut
    // ter-scroll—hanya daftar halte yang bergerak. Daftar diberi padding-atas
    // setinggi header agar baris pertama mulai tepat di bawahnya, dan ikut
    // ter-clip saat sheet mengecil (tanpa overflow). Penanda bus digambar di
    // lapisan daftar (di bawah header) sehingga tersembunyi saat baris bergeser
    // ke balik header.
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            _onScrollNotification(n);
            return false;
          },
          child: ValueListenableBuilder<double>(
            valueListenable: _scrollOffset,
            // Daftar di-cache sebagai child: tidak ikut di-rebuild saat scroll —
            // hanya penanda bus di dalam builder yang bergerak.
            child: ListView(
              controller: widget.scrollController,
              cacheExtent: 6000,
              padding: EdgeInsets.only(top: _headerExtent, bottom: 24),
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
            builder: (context, offset, child) {
              return Stack(
                children: [
                  if (child != null) child,
                  if (progress.steps.isNotEmpty)
                    Positioned(
                      left: 23,
                      top: _headerExtent + markerBaseY - offset - 13,
                      child: _BusPositionMarker(
                        color: corridorAccent(bus.corridor, theme),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        // Header dipin: tetap di atas saat daftar bergeser. Latar solid agar
        // baris/penanda yang bergeser ke atasnya tersembunyi rapi, sekaligus
        // sebagai area tarik-turun untuk menutup sheet.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _DismissDragRegion(
            key: const Key('busSheetHeader'),
            controller: widget.sheetController,
            child: ColoredBox(
              key: _headerKey,
              color: theme.colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SheetDragHandle(),
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
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      _countLabel(progress, seg, AppLocalizations.of(context)),
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
    final bool showStartEnd; // BARU: tampilkan badge Awal/Akhir di timeline

    const _Header({
      required this.bus,
      required this.origin,
      required this.destination,
      required this.fallback,
      required this.follow,
      this.showStartEnd = false, // DEFAULT: false
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
            CorridorBadge(corridor: bus.corridor),
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
                BusSpeedDial(speedKmh: speedKmh!, color: color),
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
    final dimColor = theme.colorScheme.onSurfaceVariant.withOpacity(0.55);
    final textColor = theme.colorScheme.onSurfaceVariant.withOpacity(0.75);

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
                // Nama + jarak tetap berdampingan di kiri (jarak mengikuti
                // nama seperti sebelumnya). Badge status dipisah dan dipin di
                // tepi kanan baris agar sejajar antar baris — sama seperti
                // daftar halte di Info Koridor.
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
                if (isOrigin || isFirst || isDestination || isLast)
                  const SizedBox(width: 8),
                if (isOrigin)
                  EdgeBadge(
                    label: l10n.badgeBoard,
                    icon: Icons.lens,
                    color: corridorColor,
                    filled: true,
                  )
                else if (isFirst)
                  EdgeBadge(
                    label: l10n.badgeStart,
                    icon: Icons.trip_origin,
                    color: corridorColor,
                  ),
                if (isDestination)
                  EdgeBadge(
                    label: l10n.badgeAlight,
                    icon: Icons.place,
                    color: corridorColor,
                    filled: true,
                  )
                else if (isLast)
                  EdgeBadge(
                    label: l10n.badgeEnd,
                    icon: Icons.flag,
                    color: corridorColor,
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

class _Unavailable extends StatelessWidget {
  final Bus bus;

  const _Unavailable({required this.bus});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 40),
        Icon(
          Icons.route_outlined,
          size: 56,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            AppLocalizations.of(context).halteUnavailable(bus.corridor),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
