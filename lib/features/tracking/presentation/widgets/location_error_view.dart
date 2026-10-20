import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/ui/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers.dart';

/// Tampilan galat lokasi yang menjelaskan penyebabnya dan menawarkan jalan
/// keluar (buka Pengaturan / aktifkan GPS / coba lagi).
class LocationErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final Widget? secondaryAction;

  const LocationErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.secondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kind =
        error is LocationException ? (error as LocationException).kind : null;

    final (String title, String message, IconData icon) = switch (kind) {
      LocationErrorKind.serviceDisabled => (
          l10n.locationServiceOffTitle,
          l10n.locationServiceOffMessage,
          Icons.location_off_outlined,
        ),
      LocationErrorKind.permissionDenied => (
          l10n.locationPermissionTitle,
          l10n.locationPermissionMessage,
          Icons.location_disabled_outlined,
        ),
      LocationErrorKind.permissionDeniedForever => (
          l10n.locationPermissionTitle,
          l10n.locationPermissionForeverMessage,
          Icons.location_disabled_outlined,
        ),
      null => (
          l10n.locationErrorTitle,
          error.toString(),
          Icons.location_off_outlined,
        ),
    };

    final primary = switch (kind) {
      LocationErrorKind.serviceDisabled => FilledButton.icon(
          onPressed: () => unawaited(Geolocator.openLocationSettings()),
          icon: const Icon(Icons.location_on_outlined),
          label: Text(l10n.locationEnable),
        ),
      LocationErrorKind.permissionDeniedForever => FilledButton.icon(
          onPressed: () => unawaited(Geolocator.openAppSettings()),
          icon: const Icon(Icons.settings_outlined),
          label: Text(l10n.locationOpenSettings),
        ),
      _ => FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.retry),
        ),
    };

    final showRetry = kind == LocationErrorKind.serviceDisabled ||
        kind == LocationErrorKind.permissionDeniedForever;

    return ErrorStateView(
      title: title,
      message: message,
      icon: icon,
      action: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          primary,
          if (showRetry)
            TextButton(
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          if (secondaryAction != null) secondaryAction!,
        ],
      ),
    );
  }
}
