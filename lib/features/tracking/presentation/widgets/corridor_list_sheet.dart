import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/corridor_info.dart';
import '../providers.dart';
import 'corridor_badge.dart';
import 'corridor_info_sheet.dart';
import 'format.dart';
import 'sheet_close_on_min_extent.dart';
import 'sheet_drag_handle.dart';

/// Menampilkan ringkasan seluruh koridor dalam bottom sheet berjenjang.
///
/// Dipakai dari kartu "Info Jaringan TransPadang" pada tab "Semua". Setiap
/// baris koridor dapat diketuk untuk membuka detail halte koridor tersebut
/// ([showCorridorInfoSheet]).
Future<void> showCorridorListSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Drag & handle ditangani sendiri oleh [DraggableScrollableSheet] agar
    // tidak bentrok dengan gestur modal.
    showDragHandle: false,
    enableDrag: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) => CorridorListSheet(
      onCorridorTap: (corridor) {
        Navigator.of(sheetContext).pop();
        showCorridorInfoSheet(context, corridor);
      },
    ),
  );
}

/// Bottom sheet daftar koridor: kode koridor, jumlah bus aktif, jumlah halte,
/// dan terminus tiap koridor. Ketuk satu baris untuk membuka info detailnya.
class CorridorListSheet extends ConsumerWidget {
  final ValueChanged<String> onCorridorTap;

  const CorridorListSheet({super.key, required this.onCorridorTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final infos = ref.watch(corridorInfoProvider);
    final corridors = infos.keys.toList()..sort();

    return CloseOnMinExtent(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.0,
        maxChildSize: 1.0,
        snap: true,
        builder: (context, scrollController) {
          return CustomScrollView(
            controller: scrollController,
            slivers: [
              const SliverToBoxAdapter(child: SheetDragHandle()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.infoAllCorridorsTitle,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.infoAllCorridorsHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: Divider(height: 1)),
              if (corridors.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.infoAllCorridorsEmpty,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _CorridorRow(
                        info: infos[corridors[i]]!,
                        onTap: () => onCorridorTap(corridors[i]),
                      ),
                      childCount: corridors.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: Divider(height: 1)),
              const SliverToBoxAdapter(child: _FareInfoSection()),
            ],
          );
        },
      ),
    );
  }
}

class _CorridorRow extends StatelessWidget {
  final CorridorInfo info;
  final VoidCallback onTap;

  const _CorridorRow({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = corridorAccent(info.code, theme);

    final origin = info.originPergi;
    final destination = info.destinationPergi;
    final terminus = (origin == null || destination == null)
        ? null
        : '$origin  ⇄  $destination';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Color.alphaBlend(
          accent.withOpacity(kCorridorCardTintOpacity),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                CorridorBadge(corridor: info.code, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.infoCorridorTitleCode(info.code),
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (terminus != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          terminus,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          _StatChip(
                            icon: Icons.directions_bus,
                            label: info.activeBuses == 0
                                ? l10n.infoStatNoActiveBuses
                                : l10n.infoStatActiveBuses(info.activeBuses),
                          ),
                          _StatChip(
                            icon: Icons.place_outlined,
                            label: l10n.infoStatHaltes(info.uniqueStops),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Bagian "Tarif & Pembayaran" pada sheet info jaringan: metode pembayaran,
/// daftar tarif per golongan penumpang, dan catatan aturan pembayaran.
class _FareInfoSection extends StatelessWidget {
  /// Nominal tarif (Rupiah) ditulis tetap karena tidak bergantung pada bahasa.
  static const String _generalFare = 'Rp 3.500';
  static const String _studentFare = 'Rp 1.500';

  static const List<String> _paymentMethods = <String>[
    'DEBIT',
    'KREDIT',
    'ATM',
    'QRIS',
  ];

  const _FareInfoSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 20, color: accent),
              const SizedBox(width: 8),
              Text(
                l10n.infoFareTitle,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.infoFarePaymentHint,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final method in _paymentMethods)
                _PaymentChip(label: method, accent: accent),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                accent.withOpacity(kCorridorCardTintOpacity),
                theme.colorScheme.surface,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _FareRow(
                  label: l10n.infoFareGeneral,
                  amount: _generalFare,
                  accent: accent,
                ),
                const Divider(height: 1),
                _FareRow(
                  label: l10n.infoFareStudent,
                  amount: _studentFare,
                  accent: accent,
                ),
                const Divider(height: 1),
                _FareRow(
                  label: l10n.infoFareChildOver5,
                  amount: _generalFare,
                  accent: accent,
                ),
                const Divider(height: 1),
                _FareRow(
                  label: l10n.infoFareChildUnder5,
                  amount: _studentFare,
                  accent: accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
                    l10n.infoFareNote,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String label;
  final Color accent;

  const _PaymentChip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium
            ?.copyWith(color: accent, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FareRow extends StatelessWidget {
  final String label;
  final String amount;
  final Color accent;

  const _FareRow({
    required this.label,
    required this.amount,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: theme.textTheme.titleSmall
                ?.copyWith(color: accent, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
