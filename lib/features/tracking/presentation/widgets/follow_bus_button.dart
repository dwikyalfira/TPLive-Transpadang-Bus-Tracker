import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/follow_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/bus_model.dart';
import '../../data/halte_data.dart';
import '../providers.dart';

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
      );
      if (!context.mounted) return;
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
