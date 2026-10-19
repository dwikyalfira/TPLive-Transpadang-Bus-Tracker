import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_motion.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../corridor_selector.dart';
import 'bus_map_view.dart';

/// Layar peta live TransPadang: seluruh bus di peta (penanda berwarna koridor),
/// dengan penyaring koridor dan penanda lokasi pengguna.
class MapScreen extends ConsumerWidget {
  /// Kunci bus yang langsung difokuskan saat peta dibuka (`'<koridor>|<nomor>'`).
  ///
  /// Dipakai saat peta dibuka dari detail bus: peta langsung terpusat ke bus
  /// tersebut dan kartu bus di bawah ikut tampil.
  final String? focusBusKey;

  const MapScreen({super.key, this.focusBusKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isOutsideHours = ref.watch(isOutsideHoursProvider);
    final corridors = ref.watch(allCorridorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mapTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _CorridorFilter(corridors: corridors),
        ),
      ),
      body: Stack(
        children: [
          BusMapView(focusBusKey: focusBusKey),
          if (isOutsideHours)
            Positioned(
              left: 16,
              right: 16,
              top: 12,
              child: _OutsideHoursBanner(
                title: l10n.outsideHoursTitle,
                message: l10n.outsideHoursMessage,
              ),
            ),
        ],
      ),
    );
  }
}

/// Baris penyaring koridor: chip "Semua" diikuti ikon bulat berwarna tiap
/// koridor (gaya sama dengan layar utama). Nilai terpilih disimpan di
/// [selectedCorridorProvider] agar selaras dengan tab di layar utama.
class _CorridorFilter extends ConsumerWidget {
  final List<String> corridors;

  const _CorridorFilter({required this.corridors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = ref.watch(selectedCorridorProvider);
    final palettes = [
      for (final corridor in corridors) CorridorPalette.of(corridor, theme),
    ];

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: ChoiceChip(
                label: Text(l10n.filterAll),
                selected: selected == null,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) =>
                    ref.read(selectedCorridorProvider.notifier).state = null,
              ),
            ),
          ),
          for (var i = 0; i < corridors.length; i++)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: selected == corridors[i] ? 1 : 0),
              duration: AppMotion.short4,
              curve: AppMotion.standard,
              builder: (context, value, _) => CorridorIconButton(
                corridor: corridors[i],
                palette: palettes[i],
                selFactor: value,
                onTap: () => ref
                    .read(selectedCorridorProvider.notifier)
                    .state = corridors[i],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bilah peringatan di atas peta saat di luar jam operasional.
class _OutsideHoursBanner extends StatelessWidget {
  final String title;
  final String message;

  const _OutsideHoursBanner({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF7B1FA2).withOpacity(0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.nightlight_round, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    message,
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
