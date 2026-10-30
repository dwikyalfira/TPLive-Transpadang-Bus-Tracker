import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_navigator.dart';
import '../../../../core/follow_service.dart';
import '../../../../core/theme/app_motion.dart';
import '../../data/bus_model.dart';
import '../../domain/bus_with_distance.dart';
import '../../domain/halte_tracker.dart';
import '../../domain/user_arrival.dart';
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
    final card = _cardOrNull(context, ref);

    // AnimatedSwitcher (bukan `if` biasa) supaya kartu memudar + meluncur naik
    // saat bus di-pin, dan memudar keluar saat pin dilepas/ditutup — bukan
    // hilang mendadak. `layoutBuilder` dibuat eksplisit dengan
    // [StackFit.expand] karena [FloatingPinnedBusCard] mengisi seluruh layar
    // lalu memposisikan dirinya sendiri di bawah.
    return AnimatedSwitcher(
      duration: AppMotion.medium2,
      reverseDuration: AppMotion.short4,
      switchInCurve: AppMotion.emphasizedDecelerate,
      switchOutCurve: AppMotion.emphasizedAccelerate,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: card ?? const SizedBox.shrink(key: ValueKey('pinned:none')),
    );
  }

  /// Kartu yang harus tampil, atau `null` bila tidak ada yang di-pin / kartu
  /// sedang disembunyikan (peta menampilkan kartunya sendiri, sheet detail
  /// terbuka, atau busnya belum ada di data live).
  Widget? _cardOrNull(BuildContext context, WidgetRef ref) {
    // Di layar peta, kartu bus terpilih sudah tampil di bagian bawah; sembunyikan
    // kartu pin global agar tidak menumpuk di atasnya.
    if (ref.watch(mapBusSelectedProvider)) return null;

    // Sheet detail/timeline sedang terbuka: sembunyikan kartu sepenuhnya.
    // Isinya (badge koridor, nomor bus, halte saat ini & berikutnya, progres)
    // sudah ada di sheet, dan kartu melayang digambar DI ATAS sheet sehingga
    // hanya menutupi daftar halte di bagian bawah.
    if (ref.watch(pinnedDetailOpenProvider)) return null;

    final followed = ref.watch(followedBusProvider);
    final dataset = ref.watch(halteDatasetProvider).valueOrNull;

    // Kartu beristirahat dalam mini; memelar hanya bila pengguna mengetuknya.
    final collapsed = ref.watch(pinnedCardCollapsedProvider);

    if (followed == null || dataset == null) return null;

    final bus = _find(
      ref.watch(busesProvider).valueOrNull ?? const <Bus>[],
      followed,
    );
    if (bus == null) return null;

    final progress =
        HalteTracker.trackStable(bus, dataset, estimatedHeading: bus.heading);
    if (progress == null) return null;

    // Estimasi bus datang ke lokasi pengguna. Dibaca setelah semua guard di
    // atas supaya GPS tidak dilanggankan saat tidak ada bus yang di-pin.
    final userLocation = ref.watch(userLocationProvider).valueOrNull;
    final arrival = userLocation == null
        ? null
        : UserArrival.estimate(
            busPosition: bus.position,
            user: userLocation,
            speedKmh: bus.speedKmh,
          );

    final item = BusWithDistance(
      bus: bus,
      distanceKm: arrival?.distanceKm ?? 0,
      etaMinutes: arrival?.etaMinutes,
      destinationLabel: progress.destinationLabel,
      resolvedHeading: bus.heading,
    );

    // Aksi kartu, semuanya hidup dan tidak saling menutupi:
    // * ketuk mini → memelar (mode penuh);
    // * ketuk penuh → buka detail bus (timeline);
    // * chevron di kartu penuh → kembali ke mini tanpa melepas pin;
    // * X → lepas pin (berhenti mengikuti bus).
    final VoidCallback onTap;
    if (collapsed) {
      onTap =
          () => ref.read(pinnedCardCollapsedProvider.notifier).state = false;
    } else {
      // [showBusTimeline] menandai detail terbuka (kartu disembunyikan) &
      // membersihkannya saat sheet ditutup.
      onTap = () {
        final navContext = appNavigatorKey.currentState?.overlay?.context;
        if (navContext != null) {
          showBusTimeline(navContext, item);
        }
      };
    }

    return FloatingPinnedBusCard(
      key: ValueKey('pinned:$followed'),
      bus: bus,
      progress: progress,
      collapsed: collapsed,
      arrival: arrival,
      footer: PinnedBusCardFooter(
        bus: bus,
        destinationLabel: progress.destinationLabel,
        arrival: arrival,
      ),
      onTap: onTap,
      onCollapse: () =>
          ref.read(pinnedCardCollapsedProvider.notifier).state = true,
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
