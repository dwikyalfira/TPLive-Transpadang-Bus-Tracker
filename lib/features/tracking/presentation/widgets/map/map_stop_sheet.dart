import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../domain/map_stop.dart';
import '../corridor_badge.dart';

/// Membuka ringkasan halte yang diketuk di peta.
///
/// Isinya sengaja ringkas: nama halte + koridor yang melayaninya, supaya peta
/// tetap fokus dan tidak menutupi layar.
Future<void> showMapStopSheet(BuildContext context, MapStop stop) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _MapStopSheet(stop: stop),
  );
}

class _MapStopSheet extends StatelessWidget {
  final MapStop stop;

  const _MapStopSheet({required this.stop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.directions_bus_filled_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  stop.name,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.mapStopServedBy,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final corridor in stop.corridors)
                CorridorBadge(corridor: corridor, size: 34),
            ],
          ),
        ],
      ),
    );
  }
}
