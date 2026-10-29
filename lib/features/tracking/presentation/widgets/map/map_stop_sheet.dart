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
    // Di tablet/lanskap sheet tidak melebar selebar layar.
    constraints: const BoxConstraints(maxWidth: 560),
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StopGlyph(color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    stop.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.mapStopServedBy,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final corridor in stop.corridors)
                CorridorBadge(corridor: corridor, size: 30),
            ],
          ),
        ],
      ),
    );
  }
}

/// Glyph halte: ikon papan halte di dalam lingkaran tipis berwarna aksen.
///
/// Sebelumnya memakai `Icons.directions_bus_filled_outlined` — ikon bus untuk
/// sebuah halte, dan varian "filled_outlined" membuat bentuknya terbaca aneh
/// pada ukuran 20 dp.
class _StopGlyph extends StatelessWidget {
  final Color color;

  const _StopGlyph({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.departure_board, size: 20, color: color),
    );
  }
}
