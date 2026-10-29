import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/map_mode.dart';
import '../../../../../core/settings.dart';
import '../../../../../core/theme/app_motion.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../corridor_selector.dart';
import 'bus_map_view.dart';

/// Tinggi bar penyaring koridor (sekaligus tinggi tombol saat tertutup).
const double _corridorBarHeight = 48;

/// Jarak bar penyaring dari tepi atas area peta.
const double _corridorBarTop = 8;

/// Posisi kontrol lain (banner di luar jam operasional, tombol fokus bus) agar
/// tidak tertimpa bar penyaring: tepat di bawah bar + jarak 8.
const double _topOverlayOffset = _corridorBarTop + _corridorBarHeight + 8;

/// Layar peta live TransPadang: seluruh bus di peta (penanda berwarna koridor),
/// dengan penyaring koridor, pemilih gaya peta, dan penanda lokasi pengguna.
class MapScreen extends ConsumerStatefulWidget {
  /// Kunci bus yang langsung difokuskan saat peta dibuka (`'<koridor>|<nomor>'`).
  ///
  /// Dipakai saat peta dibuka dari detail bus: peta dipersempit ke koridor bus
  /// itu, terpusat ke bus tersebut, dan kartu bus di bawah ikut tampil.
  final String? focusBusKey;

  const MapScreen({super.key, this.focusBusKey});

  /// Kunci tombol buka/tutup penyaring koridor (dipakai test).
  static const Key filterToggleKey = ValueKey('mapFilterToggle');

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOutsideHours = ref.watch(isOutsideHoursProvider);
    final corridors = ref.watch(allCorridorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mapTitle),
        actions: const [_MapModeButton()],
      ),
      body: Stack(
        children: [
          BusMapView(focusBusKey: widget.focusBusKey),
          // Penyaring koridor melayang di atas peta, bukan sebagai pita di
          // dalam AppBar: peta tetap dapat tinggi penuh dan filter terbaca
          // sebagai kontrol peta (pola yang lazim pada aplikasi peta), bukan
          // sebagai bagian dari chrome aplikasi.
          Positioned(
            left: 12,
            right: 12,
            top: 8,
            child: _CorridorFilter(corridors: corridors),
          ),
          if (isOutsideHours)
            Positioned(
              left: 16,
              right: 16,
              top: _topOverlayOffset,
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

/// Tombol pemilih gaya peta (Ikuti tema / Terang / Gelap / Satelit).
class _MapModeButton extends ConsumerWidget {
  const _MapModeButton();

  static String _label(AppLocalizations l10n, MapMode mode) => switch (mode) {
        MapMode.theme => l10n.mapModeTheme,
        MapMode.light => l10n.mapModeLight,
        MapMode.dark => l10n.mapModeDark,
        MapMode.satellite => l10n.mapModeSatellite,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(appSettingsProvider.select((s) => s.mapMode));

    return PopupMenuButton<MapMode>(
      icon: const Icon(Icons.layers_outlined),
      tooltip: l10n.mapModeTitle,
      initialValue: mode,
      onSelected: (selected) =>
          ref.read(appSettingsProvider.notifier).setMapMode(selected),
      itemBuilder: (context) => [
        for (final option in MapMode.values)
          CheckedPopupMenuItem<MapMode>(
            value: option,
            checked: option == mode,
            child: Text(_label(l10n, option)),
          ),
      ],
    );
  }
}

/// Penyaring koridor peta yang bisa dilipat.
///
/// Tertutup: satu tombol kapsul kecil di kiri-atas peta yang menampilkan
/// koridor aktif (titik warna + label). Terbuka: kapsul yang sama melebar dan
/// menampilkan chip "Semua" + ikon bulat tiap koridor (gaya sama dengan layar
/// utama). Nilainya disimpan di [mapCorridorProvider] — terpisah dari tab
/// beranda ([selectedCorridorProvider]), jadi menyaring peta tidak mengubah tab
/// yang sedang dilihat di beranda.
///
/// Kenapa dilipat: peta adalah konten utama, dan baris filter yang selalu
/// terbuka menutupi sebagian peta. Geseran atau ketukan pada peta menutupnya
/// lagi (lihat `BusMapView`), jadi pengguna tidak perlu mencari tombol tutup.
class _CorridorFilter extends ConsumerWidget {
  final List<String> corridors;

  const _CorridorFilter({required this.corridors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = ref.watch(mapCorridorProvider);
    final expanded = ref.watch(mapFilterExpandedProvider);
    final palettes = [
      for (final corridor in corridors) CorridorPalette.of(corridor, theme),
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedSize(
        duration: AppMotion.short4,
        curve: AppMotion.standard,
        alignment: Alignment.centerLeft,
        child: Material(
          // Solid (bukan transparan) agar tetap terbaca di atas citra satelit.
          color: theme.colorScheme.surface,
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_corridorBarHeight / 2),
            side: BorderSide(color: theme.dividerColor.withOpacity(0.6)),
          ),
          child: SizedBox(
            height: _corridorBarHeight,
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                _FilterToggle(
                  key: MapScreen.filterToggleKey,
                  expanded: expanded,
                  selected: selected,
                  onTap: () => ref
                      .read(mapFilterExpandedProvider.notifier)
                      .state = !expanded,
                ),
                if (expanded)
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 8),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Center(
                            child: ChoiceChip(
                              label: Text(l10n.filterAll),
                              selected: selected == null,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onSelected: (_) => ref
                                  .read(mapCorridorProvider.notifier)
                                  .state = null,
                            ),
                          ),
                        ),
                        for (var i = 0; i < corridors.length; i++)
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0,
                              end: selected == corridors[i] ? 1 : 0,
                            ),
                            duration: AppMotion.short4,
                            curve: AppMotion.standard,
                            builder: (context, value, _) => CorridorIconButton(
                              corridor: corridors[i],
                              palette: palettes[i],
                              selFactor: value,
                              onTap: () => ref
                                  .read(mapCorridorProvider.notifier)
                                  .state = corridors[i],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol buka/tutup penyaring koridor: **hanya** chevron horizontal yang
/// berputar 180° saat terbuka — arah panahnya mengikuti arah buka kapsul (ke
/// samping, bukan ke bawah).
///
/// Titik warna & label koridor tidak lagi ditampilkan: koridor aktif sudah
/// terbaca dari warna rute di peta, dan tombol selebar satu ikon membuat peta
/// tidak tertutup. Konsekuensinya informasi itu hilang untuk pembaca layar,
/// jadi tetap diteruskan lewat `Semantics.value`.
class _FilterToggle extends StatelessWidget {
  final bool expanded;
  final String? selected;
  final VoidCallback onTap;

  const _FilterToggle({
    super.key,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      expanded: expanded,
      label: l10n.mapFilterTitle,
      value: selected ?? l10n.filterAll,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          // Persegi setinggi kapsul → saat tertutup bentuknya lingkaran penuh.
          width: _corridorBarHeight,
          height: _corridorBarHeight,
          child: Center(
            // Chevron horizontal, bukan vertikal: kapsul ini membuka ke
            // samping (daftar koridor mengalir ke kanan), jadi panah
            // atas/bawah menjanjikan arah gerak yang keliru. Satu ikon
            // diputar setengah putaran supaya arahnya beranimasi, bukan
            // berganti mendadak.
            child: AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: AppMotion.short4,
              curve: AppMotion.standard,
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
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
