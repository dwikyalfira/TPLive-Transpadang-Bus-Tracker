import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_navigator.dart';
import '../../../../core/follow_service.dart';
import '../../data/bus_model.dart';
import '../../domain/bus_with_distance.dart';
import '../../domain/halte_tracker.dart';
import '../providers.dart';
import 'floating_pinned_bus_card.dart';
import 'halte_timeline_sheet.dart';

/// Membungkus [Navigator] dengan pendeteksi guliran + [PinnedBusOverlay].
///
/// Digunakan lewat `MaterialApp.builder`. Saat pengguna menggulir layar,
/// kartu bus di-pin mengecil (hanya garis progres); saat mulai gulir ke atas
/// atau kembali ke puncak, kartu memelar lagi.
class RootOverlay extends ConsumerWidget {
  /// Subtree Navigator (anak dari `MaterialApp.builder`).
  final Widget child;

  const RootOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _onScroll(ref, notification);
            return false;
          },
          child: child,
        ),
        const PinnedBusOverlay(),
      ],
    );
  }

  /// Mengubah status [pinnedCardCollapsedProvider] menjadi mini pada setiap
  /// guliran vertikal dari scrollable mana pun di seluruh halaman. Kartu
  /// hanya memelar bila pengguna menyengajanya (mengetuk kartu).
  static void _onScroll(WidgetRef ref, ScrollNotification notification) {
    if (ref.read(followedBusProvider) == null) return;
    if (notification is! ScrollUpdateNotification) return;
    if (notification.metrics.axis != Axis.vertical) return;

    ref.read(pinnedCardCollapsedProvider.notifier).state = true;
  }
}

/// Overlay global yang menampilkan [FloatingPinnedBusCard] untuk bus yang
/// sedang di-pin.
///
/// Dipasang di atas [Navigator] (lewat [RootOverlay]) sehingga kartu tetap
/// terlihat saat berpindah halaman. Bus dicari dari **semua** bus (bukan bus
/// terdekat yang tersaring koridor) agar kartu tetap tampil di semua
/// halaman/filter koridor. Tidak menghalangi sentuhan di luar area kartu.
class PinnedBusOverlay extends ConsumerWidget {
  const PinnedBusOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Di layar peta, kartu bus terpilih sudah tampil di bagian bawah; sembunyikan
    // kartu pin global agar tidak menumpuk di atasnya.
    if (ref.watch(mapBusSelectedProvider)) return const SizedBox.shrink();

    final followed = ref.watch(followedBusProvider);
    final dataset = ref.watch(halteDatasetProvider).valueOrNull;

    final detailOpen = ref.watch(pinnedDetailOpenProvider);

    // Kartu beristirahat dalam mini; saat detail terbuka, kartu dipaksa mini
    // (tidak ikut memelar walau timeline digulir).
    final collapsed =
        detailOpen || ref.watch(pinnedCardCollapsedProvider);

    if (followed == null || dataset == null) return const SizedBox.shrink();

    final bus = _find(
      ref.watch(busesProvider).valueOrNull ?? const <Bus>[],
      followed,
    );
    if (bus == null) return const SizedBox.shrink();

    final progress =
        HalteTracker.track(bus, dataset, estimatedHeading: bus.heading);
    if (progress == null) return const SizedBox.shrink();

    final item = BusWithDistance(
      bus: bus,
      distanceKm: 0,
      etaMinutes: null,
      resolvedHeading: bus.heading,
    );

    VoidCallback? onTap;
    if (detailOpen) {
      // Detail sudah terbuka; kartu mini tidak perlu disentuh.
      onTap = null;
    } else if (collapsed) {
      // Mini → ketuk untuk memelar (menampilkan status & tombol tutup).
      onTap = () =>
          ref.read(pinnedCardCollapsedProvider.notifier).state = false;
    } else {
      // Memelar → ketuk untuk membuka detail bus. [showBusTimeline] menandai
      // detail terbuka (kartu jadi mini) & membersihkannya saat sheet ditutup.
      onTap = () {
        final navContext = appNavigatorKey.currentState?.overlay?.context;
        if (navContext != null) {
          showBusTimeline(navContext, item);
        }
      };
    }

    return FloatingPinnedBusCard(
      bus: bus,
      progress: progress,
      collapsed: collapsed,
      footer: PinnedBusCardFooter(
        bus: bus,
        destinationLabel: progress.destinationLabel,
      ),
      onTap: onTap,
      onClose: () {
        ref.read(followedBusProvider.notifier).state = null;
        FollowService.stopFollow();
      },
    );
  }

  Bus? _find(List<Bus> buses, String key) {
    for (final b in buses) {
      if (busFollowKey(b.corridor, b.number) == key) return b;
    }
    return null;
  }
}