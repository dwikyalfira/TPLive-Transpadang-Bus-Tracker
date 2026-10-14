import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/bus_with_distance.dart';
import 'format.dart';

/// Kartu satu bus pada daftar bus terdekat.
class BusTile extends StatelessWidget {
  final BusWithDistance item;
  final VoidCallback? onTap;

  /// Tampilkan baris "Tujuan …" di dalam kartu. Dimatikan bila tujuan sudah
  /// ditampilkan sebagai judul kelompok.
  final bool showDestination;

  const BusTile({
    super.key,
    required this.item,
    this.onTap,
    this.showDestination = true,
  });

  @override
  Widget build(BuildContext context) {
    final bus = item.bus;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final nowUtc = DateTime.now().toUtc();
    final accent = corridorAccent(bus.corridor, theme);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CorridorBadge(corridor: bus.corridor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.busLabel(bus.number),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (showDestination &&
                            item.destinationLabel != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(Icons.navigation,
                                    size: 14,
                                    color: theme.colorScheme.primary),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  l10n.destinationLabel(item.destinationLabel!),
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatDistance(item.distanceKm),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Baris bawah: waktu pembaruan (kiri) & perkiraan waktu tiba
              // (kanan) dibuat sejajar.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.updatedLabel(formatAge(bus.age(nowUtc), l10n)),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    item.etaMinutes != null
                        ? l10n.etaApprox(item.etaMinutes!)
                        : l10n.etaUnknown,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CorridorBadge extends StatelessWidget {
  final String corridor;

  const _CorridorBadge({required this.corridor});

  @override
  Widget build(BuildContext context) {
    final color = corridorAccent(corridor, Theme.of(context));
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        corridor.isEmpty ? '?' : corridor,
        style: TextStyle(
          color: onColor(color),
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }
}
