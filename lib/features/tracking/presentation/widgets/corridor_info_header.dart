import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers.dart';
import 'corridor_info_sheet.dart';
import 'corridor_list_sheet.dart';
import 'format.dart';

/// Kartu ringkas "Info Koridor" di atas daftar bus tiap tab.
///
/// Menampilkan sekilas jumlah bus aktif, jumlah halte, dan terminus
/// asal⇄tujuan. [corridor] bernilai `null` untuk tab "Semua" yang memakai
/// ringkasan seluruh jaringan. Ketuk kartu koridor untuk membuka detail
/// ([showCorridorInfoSheet]).
class CorridorInfoHeader extends ConsumerWidget {
  final String? corridor;

  const CorridorInfoHeader({super.key, this.corridor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (corridor == null) {
      final net = ref.watch(networkInfoProvider);
      return _Shell(
        accent: theme.colorScheme.primary,
        badgeLabel: null,
        title: l10n.infoNetworkTitle,
        stats: [
          _Stat(
            icon: Icons.directions_bus,
            label: net.activeBuses == 0
                ? l10n.infoStatNoActiveBuses
                : l10n.infoStatActiveBuses(net.activeBuses),
          ),
          _Stat(
            icon: Icons.route_outlined,
            label: l10n.infoStatCorridors(net.corridorCount),
          ),
          _Stat(
            icon: Icons.place_outlined,
            label: l10n.infoStatHaltes(net.uniqueStops),
          ),
        ],
        onTap: () => showCorridorListSheet(context),
      );
    }

    final info = ref
        .watch(corridorInfoProvider.select((m) => m[corridor!.toUpperCase()]));
    if (info == null) return const SizedBox.shrink();
    final accent = corridorAccent(corridor!, theme);

    final origin = info.originPergi;
    final destination = info.destinationPergi;
    final terminus = (origin == null || destination == null)
        ? null
        : '$origin  ⇄  $destination';

    return _Shell(
      accent: accent,
      badgeLabel: corridor,
      title: l10n.infoCorridorTitleCode(corridor!),
      stats: [
        _Stat(
          icon: Icons.directions_bus,
          label: info.activeBuses == 0
              ? l10n.infoStatNoActiveBuses
              : l10n.infoStatActiveBuses(info.activeBuses),
        ),
        _Stat(
          icon: Icons.place_outlined,
          label: l10n.infoStatHaltes(info.uniqueStops),
        ),
      ],
      terminus: terminus,
      onTap: () => showCorridorInfoSheet(context, corridor!),
    );
  }
}

class _Stat {
  final IconData icon;
  final String label;

  const _Stat({required this.icon, required this.label});
}

class _Shell extends StatelessWidget {
  final Color accent;
  final String? badgeLabel;
  final String title;
  final List<_Stat> stats;
  final String? terminus;
  final VoidCallback? onTap;

  const _Shell({
    required this.accent,
    required this.badgeLabel,
    required this.title,
    required this.stats,
    this.terminus,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final terminusText = terminus;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (badgeLabel != null) ...[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: accent, shape: BoxShape.circle),
                  child: Text(
                    badgeLabel!,
                    style: TextStyle(
                      color: onColor(accent),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    for (final stat in stats) _statChip(context, stat),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          if (terminusText != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.navigation, size: 14, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    terminusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: Color.alphaBlend(
          accent.withOpacity(kCorridorCardTintOpacity),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(16),
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: content,
              ),
      ),
    );
  }

  Widget _statChip(BuildContext context, _Stat stat) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(stat.icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          stat.label,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
