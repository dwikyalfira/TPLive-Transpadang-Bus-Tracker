import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/halte_data.dart';
import '../../domain/corridor_info.dart';
import '../providers.dart';
import 'corridor_badge.dart';
import 'format.dart';
import 'sheet_close_on_min_extent.dart';
import 'sheet_drag_handle.dart';

/// Menampilkan detail info sebuah koridor dalam bottom sheet berjenjang.
///
/// Mengikuti panduan Material 3: sheet dibuka pada 50% tinggi layar, dapat
/// ditarik ke atas hingga penuh, dan memiliki drag handle (dapat digulir untuk
/// mengubah tinggi). Perilaku berjenjang ini ditangani oleh
/// [DraggableScrollableSheet] di dalam modal.
///
/// [useSafeArea] diaktifkan agar tinggi penuh sheet berhenti di bawah bar
/// notifikasi (hanya menutupi area aplikasi), bukan menembus status bar.
Future<void> showCorridorInfoSheet(BuildContext context, String corridor) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Drag & handle ditangani sendiri oleh [DraggableScrollableSheet] agar
    // tidak bentrok dengan gestur modal.
    showDragHandle: false,
    enableDrag: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => CorridorInfoSheet(corridor: corridor),
  );
}

/// Bottom sheet "Info Koridor": jumlah bus aktif, jumlah halte (per arah &
/// unik), terminus asal→tujuan tiap arah, dan daftar lengkap halte.
///
/// Seluruh isi berada dalam satu [CustomScrollView] yang memakai scroll
/// controller dari [DraggableScrollableSheet], sehingga menarik dari bagian
/// mana pun (termasuk header) mengubah tinggi sheet — bukan hanya daftarnya.
class CorridorInfoSheet extends ConsumerStatefulWidget {
  final String corridor;

  const CorridorInfoSheet({super.key, required this.corridor});

  @override
  ConsumerState<CorridorInfoSheet> createState() => _CorridorInfoSheetState();
}

class _CorridorInfoSheetState extends ConsumerState<CorridorInfoSheet> {
  /// Arah yang sedang ditampilkan pada daftar halte (true = pergi).
  bool _pergi = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = corridorAccent(widget.corridor, theme);
    final info = ref.watch(
        corridorInfoProvider.select((m) => m[widget.corridor.toUpperCase()]));
    final datasetAsync = ref.watch(halteDatasetProvider);

    return CloseOnMinExtent(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        // 0.0 agar menarik turun (gulir ke bawah) dapat langsung mengecilkan
        // sheet hingga menutup tanpa terhenti di titik minimum lama (0.25).
        minChildSize: 0.0,
        maxChildSize: 1.0,
        snap: true,
        builder: (context, scrollController) {
          final slivers = <Widget>[
            const SliverToBoxAdapter(child: SheetDragHandle()),
          ];

          datasetAsync.when(
            loading: () => slivers.add(
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => slivers.add(
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.halteDataLoadFailed('$e'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            data: (dataset) {
              final stops = dataset.forCorridor(widget.corridor);
              final resolved =
                  info ?? CorridorInfo.of(widget.corridor, stops, 0);
              final direction = _pergi ? stops?.pergi : stops?.pulang;

              slivers.add(SliverToBoxAdapter(
                child: _Header(
                  l10n: l10n,
                  theme: theme,
                  accent: accent,
                  info: resolved,
                  pergi: _pergi,
                  onDirectionChanged: (pergi) => setState(() => _pergi = pergi),
                ),
              ));
              slivers.add(const SliverToBoxAdapter(child: Divider(height: 1)));

              if (direction == null) {
                slivers.add(SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.halteUnavailable(widget.corridor),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ));
                return;
              }

              slivers.add(SliverPadding(
                padding: const EdgeInsets.only(top: 6),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _HalteRow(
                      index: i,
                      total: direction.halte.length,
                      halte: direction.halte[i],
                      accent: accent,
                    ),
                    childCount: direction.halte.length,
                  ),
                ),
              ));
              slivers.add(SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.infoOperationalHours,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DataDisclaimer(
                        text: l10n.infoDataDisclaimer,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ));
            },
          );

          return CustomScrollView(
              controller: scrollController, slivers: slivers);
        },
      ),
    );
  }
}

/// Catatan di bagian bawah sheet: mengingatkan bahwa data halte dapat berbeda
/// dari kondisi asli di lapangan karena pembaruan atau keterbatasan data
/// terbaru.
class _DataDisclaimer extends StatelessWidget {
  final String text;
  final ThemeData theme;

  const _DataDisclaimer({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final Color accent;
  final CorridorInfo info;
  final bool pergi;
  final ValueChanged<bool> onDirectionChanged;

  const _Header({
    required this.l10n,
    required this.theme,
    required this.accent,
    required this.info,
    required this.pergi,
    required this.onDirectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final route = info.routeName?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CorridorBadge(corridor: info.code),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.infoCorridorTitleCode(info.code),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (route != null && route.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        route,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatTile(
                value: '${info.activeBuses}',
                label: l10n.infoActiveBusesLabel,
                accent: accent,
                theme: theme,
              ),
              const SizedBox(width: 8),
              _StatTile(
                value: '${info.totalStops}',
                label: l10n.infoTotalStopsLabel,
                accent: accent,
                theme: theme,
              ),
              const SizedBox(width: 8),
              _StatTile(
                value: '${info.uniqueStops}',
                label: l10n.infoUniqueStopsLabel,
                accent: accent,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TerminusCard(
            label: l10n.infoDirectionPergi,
            origin: info.originPergi,
            destination: info.destinationPergi,
            stops: info.stopsPergi,
            accent: accent,
            theme: theme,
            l10n: l10n,
          ),
          const SizedBox(height: 8),
          _TerminusCard(
            label: l10n.infoDirectionPulang,
            origin: info.originPulang,
            destination: info.destinationPulang,
            stops: info.stopsPulang,
            accent: accent,
            theme: theme,
            l10n: l10n,
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment<bool>(
                value: true,
                label: Text(l10n.infoDirectionPergi),
                icon: const Icon(Icons.arrow_forward, size: 16),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text(l10n.infoDirectionPulang),
                icon: const Icon(Icons.arrow_back, size: 16),
              ),
            ],
            selected: {pergi},
            onSelectionChanged: (selection) =>
                onDirectionChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color accent;
  final ThemeData theme;

  const _StatTile({
    required this.value,
    required this.label,
    required this.accent,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: accent, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminusCard extends StatelessWidget {
  final String label;
  final String? origin;
  final String? destination;
  final int stops;
  final Color accent;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _TerminusCard({
    required this.label,
    required this.origin,
    required this.destination,
    required this.stops,
    required this.accent,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: accent, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                l10n.countHalte(stops),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  origin ?? l10n.unknown,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 16, color: accent),
              ),
              Expanded(
                child: Text(
                  destination ?? l10n.unknown,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HalteRow extends StatelessWidget {
  final int index;
  final int total;
  final Halte halte;
  final Color accent;

  const _HalteRow({
    required this.index,
    required this.total,
    required this.halte,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isFirst = index == 0;
    final isLast = index == total - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: accent, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              halte.nama,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          if (isFirst)
            EdgeBadge(
              label: l10n.badgeStart,
              icon: Icons.trip_origin,
              color: accent,
            ),
          if (isLast)
            EdgeBadge(
              label: l10n.badgeEnd,
              icon: Icons.flag,
              color: accent,
            ),
        ],
      ),
    );
  }
}
