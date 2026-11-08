import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/follow_service.dart';
import '../../../../core/settings.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/bus_model.dart';
import '../../data/halte_data.dart';
import '../providers.dart';
import 'format.dart';

/// Data yang dibutuhkan untuk fitur "ikuti bus" (notifikasi).
class FollowPayload {
  final String originLabel;
  final String destinationLabel;
  final String route;
  final String directionKey;
  final List<Halte> haltes;

  const FollowPayload({
    required this.originLabel,
    required this.destinationLabel,
    required this.route,
    required this.directionKey,
    required this.haltes,
  });
}

/// Tombol ikuti/berhenti mengikuti bus (pin notifikasi).
///
/// Dipakai di dalam bottom sheet detail bus maupun kartu bus di layar rute.
class FollowBusButton extends ConsumerWidget {
  final Bus bus;
  final FollowPayload payload;

  /// Warna saat aktif (mengikuti). Default: warna primer tema.
  final Color? activeColor;

  const FollowBusButton({
    super.key,
    required this.bus,
    required this.payload,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Notifikasi foreground service hanya ada di Android; di web tombolnya
    // disembunyikan agar tidak menjadi elemen mati.
    if (kIsWeb) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final key = busFollowKey(bus.corridor, bus.number);
    final isFollowing = ref.watch(followedBusProvider) == key;
    final color = activeColor ?? theme.colorScheme.primary;

    return IconButton(
      tooltip: isFollowing ? l10n.tooltipUnfollow : l10n.tooltipFollow,
      onPressed: () => _toggle(context, ref, key, isFollowing),
      icon: Icon(
        isFollowing
            ? Icons.notifications_active
            : Icons.notifications_none_outlined,
      ),
      color: isFollowing ? color : theme.colorScheme.onSurfaceVariant,
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    String key,
    bool currentlyFollowing,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (currentlyFollowing) {
      ref.read(followedBusProvider.notifier).state = null;
      ref.read(boardingStatusProvider.notifier).state =
          FollowService.boardingFollowing;
      await FollowService.stopFollow();
      return;
    }

    final granted = await FollowService.requestNotificationPermission();
    if (!context.mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.notifPermissionDenied)),
      );
      return;
    }

    try {
      await FollowService.startFollow(
        corridor: bus.corridor,
        busNumber: bus.number,
        origin: payload.originLabel,
        destination: payload.destinationLabel,
        route: payload.route,
        direction: payload.directionKey,
        haltes: payload.haltes,
        accentColor: corridorColor(bus.corridor).value,
        autoStopOnAlight: ref.read(appSettingsProvider).autoStopOnAlight,
        labels: {
          'title': bus.number.trim().isEmpty
              ? l10n.notifFollowTitleGeneric(bus.corridor)
              : l10n.notifFollowTitle(bus.number, bus.corridor),
          // Template diberi penanda yang diganti oleh layanan native dengan
          // nilai yang berubah tiap snapshot (nama halte, jarak, ETA).
          'headingTo': l10n.notifHeadingTo('__STOP__'),
          'distanceToNextStop': l10n.notifDistanceToNext('__DISTANCE__'),
          'eta': l10n.notifEta('__MINUTES__'),
          'searchingNext': l10n.notifSearchingNext,
          'searchingSignal': l10n.notifSearchingSignal,
          'destinationFallback': l10n.notifDestinationFallback,
          'stopAction': l10n.notifStopAction,
          'onboardBadge': l10n.notifOnboardBadge,
          'wearNoBus': l10n.notifWearNoBus,
          'etaToYou': l10n.notifEtaToUser('__MINUTES__'),
          'busNearYou': l10n.notifBusNearYou,
          'wearMapHint': l10n.notifWearMapHint,
          'alightedTitle': l10n.notifAlightedTitle,
          'alightedBody': l10n.notifAlightedBody,
          'eventChannelName': l10n.notifEventChannelName,
          'eventChannelDescription': l10n.notifEventChannelDescription,
          'stopFallback': l10n.notifStopFallback('__INDEX__'),
          'channelName': l10n.notifChannelName,
          'channelDescription': l10n.notifChannelDescription,
        },
      );
      if (!context.mounted) return;
      ref.read(boardingStatusProvider.notifier).state =
          FollowService.boardingFollowing;
      ref.read(followedBusProvider.notifier).state = key;
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.followFailed(e.message ?? ''))),
      );
    } on MissingPluginException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.followUnavailable)),
      );
    }
  }
}
