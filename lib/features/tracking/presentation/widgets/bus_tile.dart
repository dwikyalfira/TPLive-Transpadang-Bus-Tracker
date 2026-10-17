import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/bus_with_distance.dart';
import 'corridor_badge.dart';
import 'format.dart';

/// Kartu satu bus pada daftar bus terdekat.
class BusTile extends StatelessWidget {
  final BusWithDistance item;
  final VoidCallback? onTap;

  /// Tampilkan baris "Tujuan …" di dalam kartu. Dimatikan bila tujuan sudah
  /// ditampilkan sebagai judul kelompok.
  final bool showDestination;

  /// Widget opsional di ujung kanan baris atas (mis. tombol tutup pada kartu
  /// peta). `null` pada daftar biasa.
  final Widget? trailing;

  const BusTile({
    super.key,
    required this.item,
    this.onTap,
    this.showDestination = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final bus = item.bus;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final nowUtc = DateTime.now().toUtc();

    // Latar kartu memakai resep yang sama dengan kartu "Info Koridor" per
    // koridor (tint aksen di atas [surface]) supaya keduanya menyatu. Warna
    // teks/ikon di atasnya memakai [corridorOnBackground] agar tetap kontras
    // (mis. amber K2).
    final cardColor = corridorSurfaceTint(
      bus.corridor,
      theme,
      base: theme.colorScheme.surface,
    );
    final onCardAccent = corridorOnBackground(bus.corridor, cardColor);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CorridorBadge(corridor: bus.corridor),
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
                                    size: 14, color: onCardAccent),
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
                  if (trailing != null) ...[
                    const SizedBox(width: 4),
                    trailing!,
                  ],
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
                      color: onCardAccent,
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
