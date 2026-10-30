import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/map_mode.dart';
import '../../../../../core/settings.dart';
import '../../../../../core/theme/app_motion.dart';
import '../../../../../core/ui/reveal.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../corridor_selector.dart';
import 'bus_map_view.dart';

/// Tinggi bar penyaring koridor (sekaligus tinggi tombol saat tertutup).
const double _corridorBarHeight = 48;

/// Jarak bar penyaring dari tepi atas area peta.
const double _corridorBarTop = 8;

/// Inset kiri/kanan untuk **semua** kontrol melayang di peta. Kapsul penyaring
/// dan kartu status memakai angka yang sama supaya tepi kirinya sejajar —
/// dulu kartu memakai 16 sementara kapsul 12, jadi keduanya terlihat bergeser.
const double _overlayInset = 12;

/// Tepi atas kartu status "tidak melayani": tepat di bawah kapsul penyaring
/// ditambah jarak 12, supaya tidak menempel pada tombol bulat di kiri-atas.
const double _statusCardTop = _corridorBarTop + _corridorBarHeight + 12;

/// Lebar maksimum kartu status. Di ponsel kartu memenuhi lebar layar; di tablet
/// dan mode lanskap ia berhenti melebar agar tidak menjadi pita raksasa.
const double _statusCardMaxWidth = 520;

/// Durasi & kurva buka/tutup kontrol melayang di peta (kapsul penyaring koridor
/// dan kartu status). Satu nilai untuk keduanya supaya keduanya bergerak
/// seirama; [AppMotion.medium1] dipakai (bukan short4) agar tersingkapnya isi
/// sempat terbaca sebagai gerakan, bukan sekadar kedipan.
const Duration _mapRevealDuration = AppMotion.medium1;
const Curve _mapRevealCurve = AppMotion.emphasizedDecelerate;

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

  /// Kunci kartu status "sedang tidak melayani penumpang" (dipakai test).
  static const Key outsideHoursCardKey = ValueKey('mapOutsideHoursCard');

  /// Kunci ikon status (tombol buka/lipat kartu "tidak melayani", dipakai test).
  static const Key outsideHoursIconKey = ValueKey('mapOutsideHoursIcon');

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
            left: _overlayInset,
            right: _overlayInset,
            top: _corridorBarTop,
            child: _CorridorFilter(corridors: corridors),
          ),
          // Kartu status diletakkan di bawah kapsul penyaring dengan jarak yang
          // jelas, tepinya sejajar dengan kapsul, dan lebarnya dibatasi supaya
          // tetap terbaca sebagai kartu — bukan pita yang menempel ke tepi atas
          // peta. SafeArea menjaga teks tidak masuk ke area ponco/lengkung layar
          // saat perangkat diputar.
          //
          // Kartu ini bisa dilipat jadi satu ikon (lihat
          // [mapStatusExpandedProvider]): saat pengguna sedang menelusuri peta,
          // bilah informasi selebar layar hanya menghalangi.
          if (isOutsideHours)
            Positioned(
              left: 0,
              right: 0,
              top: _statusCardTop,
              child: SafeArea(
                top: false,
                bottom: false,
                minimum: const EdgeInsets.symmetric(horizontal: _overlayInset),
                child: Align(
                  // Kiri-atas, bukan tengah: ikon versi terlipat harus duduk
                  // sekolom dengan kapsul penyaring di atasnya.
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: _statusCardMaxWidth),
                    child: _OutsideHoursStatus(
                      expanded: ref.watch(mapStatusExpandedProvider),
                      title: l10n.outsideHoursTitle,
                      message: l10n.outsideHoursMessage,
                      onToggle: () => ref
                          .read(mapStatusExpandedProvider.notifier)
                          .state = !ref.read(mapStatusExpandedProvider),
                    ),
                  ),
                ),
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
          // [RevealRow] menggantikan AnimatedSize: chip tidak lagi muncul
          // mendadak di ujung animasi, tapi tersingkap sambil memudar masuk.
          child: RevealRow(
            open: expanded,
            duration: _mapRevealDuration,
            curve: _mapRevealCurve,
            leading: _FilterToggle(
              key: MapScreen.filterToggleKey,
              expanded: expanded,
              selected: selected,
              onTap: () => ref
                  .read(mapFilterExpandedProvider.notifier)
                  .state = !expanded,
            ),
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
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
              duration: _mapRevealDuration,
              curve: _mapRevealCurve,
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

/// Status "sedang tidak melayani penumpang" di atas peta, bisa dilipat.
///
/// Bentuk & animasinya **meniru kapsul penyaring koridor** di atasnya
/// ([_CorridorFilter]): permukaan `surface` solid dengan garis tepi tipis,
/// elevasi 3, sudut membulat `tinggi/2`, dan `AnimatedSize` yang membesar dari
/// kiri (`Alignment.centerLeft`) dengan durasi/kurva yang sama. Hasilnya kedua
/// kontrol di kolom kiri-atas peta terasa satu keluarga, dan tombol bulat saat
/// terlipat berukuran sama persis dengan tombol penyaring (48 dp).
///
/// **Ikon adalah satu-satunya kontrol**: mengetuk ikon bulan membuka teks
/// lengkap, mengetuknya lagi melipat kembali ke ikon saja. Tidak ada tombol
/// panah terpisah. Mengetuk peta juga melipatnya otomatis (lihat `BusMapView`),
/// supaya bilah informasi tidak menghalangi saat peta ditelusuri. Statusnya
/// disimpan di [mapStatusExpandedProvider] sehingga tidak hilang saat peta
/// dibangun ulang.
class _OutsideHoursStatus extends StatelessWidget {
  final bool expanded;
  final String title;
  final String message;
  final VoidCallback onToggle;

  const _OutsideHoursStatus({
    required this.expanded,
    required this.title,
    required this.message,
    required this.onToggle,
  });

  /// Ungu malam: pekat di tema terang, dicerahkan di tema gelap supaya
  /// kontras ikon/judul terhadap `surface` gelap tetap cukup.
  static const Color _night = Color(0xFF7B1FA2);
  static const Color _nightDark = Color(0xFFCE93D8);

  /// Ukuran tombol ikon = tinggi kapsul penyaring koridor, jadi kedua tombol di
  /// kolom kiri peta tampil sejajar dan sama besar.
  static const double _circleSize = _corridorBarHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.brightness == Brightness.dark ? _nightDark : _night;

    // Bentuk & gerak sama dengan kapsul penyaring: [RevealRow] menyingkap isi
    // dari tepi kiri sambil memudarkannya, jadi ikon tidak "melompat" dan teks
    // tidak muncul mendadak di ujung animasi.
    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_corridorBarHeight / 2),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.6)),
      ),
      child: RevealRow(
        open: expanded,
        revealHeight: true,
        duration: _mapRevealDuration,
        curve: _mapRevealCurve,
        leading: _iconButton(context, accent, isExpanded: expanded),
        child: _text(context, theme, accent),
      ),
    );
  }

  Widget _text(BuildContext context, ThemeData theme, Color accent) {
    return GestureDetector(
      key: MapScreen.outsideHoursCardKey,
      // Teks tidak ikut menutup kartu saat diketuk: ketukan di area kartu
      // ditahan di sini, jadi hanya ketukan di peta yang melipatnya.
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8, right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tombol ikon 48 dp yang dipakai di kedua keadaan, supaya ikon bulan tidak
  /// melompat saat kartu dibuka/dilipat. Ketukan di sini membuka/melipat teks.
  ///
  /// Saat terlipat seluruh teks tetap diteruskan ke pembaca layar lewat
  /// `Semantics`, jadi menyembunyikan kartu tidak menghilangkan informasinya
  /// untuk aksesibilitas.
  Widget _iconButton(
    BuildContext context,
    Color accent, {
    required bool isExpanded,
  }) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      expanded: isExpanded,
      label: isExpanded ? l10n.tooltipClose : title,
      value: isExpanded ? null : message,
      child: InkWell(
        key: MapScreen.outsideHoursIconKey,
        onTap: onToggle,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          width: _circleSize,
          height: _circleSize,
          child: Center(
            child: Icon(Icons.nightlight_round, size: 20, color: accent),
          ),
        ),
      ),
    );
  }
}
