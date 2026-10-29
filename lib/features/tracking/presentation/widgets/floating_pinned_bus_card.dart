import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/bus_model.dart';
import '../../domain/geo_utils.dart' as geo;
import '../../domain/halte_tracker.dart';
import '../../domain/user_arrival.dart';
import 'format.dart';
import 'speed_dial.dart';

/// Kartu bus yang sedang di-pin ("update island"), melayang di bagian bawah
/// layar sehingga tetap terlihat di atas konten lain.
///
/// Dibangun dengan [Stack] + [Positioned] agar mudah ditumpuk (overlay).
/// Seluruh informasi posisi halte diambil dari [HalteProgress] yang
/// dihasilkan [HalteTracker].
///
/// Bila [collapsed] benar, kartu hanya menampilkan garis progres — dipakai
/// saat pengguna menggulir layar agar area konten lebih luas terlihat.
///
/// Contoh pemakaian sebagai overlay:
/// ```dart
/// Stack(
///   children: [
///     KontenUtama(),
///     if (progress != null)
///       FloatingPinnedBusCard(
///         bus: bus,
///         progress: progress,
///         collapsed: collapsed,
///         onTap: () => detail(),
///         onClose: () => stopFollow(),
///       ),
///   ],
/// )
/// ```
class FloatingPinnedBusCard extends StatelessWidget {
  /// Bus yang sedang di-pin.
  final Bus bus;

  /// Posisi bus relatif terhadap timeline halte koridornya.
  final HalteProgress progress;

  /// Bila benar, hanya garis progres yang ditampilkan (mode ringkas).
  final bool collapsed;

  /// Dipanggil saat kartu diketuk (mis. untuk membuka detail) — saat [collapsed]
  /// pemanggil diharapkan memelarkan kartu.
  final VoidCallback? onTap;

  /// Dipanggil saat tombol tutup ditekan (mis. untuk berhenti mengikuti).
  final VoidCallback? onClose;

  /// Dipanggil saat tombol "kecilkan" ditekan (kembali ke mode mini tanpa
  /// melepas pin). Null = tombol tidak ditampilkan.
  final VoidCallback? onCollapse;

  /// Rincian tambahan opsional pada mode penuh (mis. [PinnedBusCardFooter]).
  final Widget? footer;

  /// Perkiraan kedatangan bus ini ke lokasi pengguna (opsional).
  ///
  /// Pada mode mini hanya menitnya yang tampil sebagai chip kecil di kanan
  /// judul; pada mode penuh angkanya juga muncul di [footer] pemanggil.
  final UserArrival? arrival;

  const FloatingPinnedBusCard({
    super.key,
    required this.bus,
    required this.progress,
    this.collapsed = false,
    this.onTap,
    this.onClose,
    this.onCollapse,
    this.footer,
    this.arrival,
  });

  /// Kunci untuk mengukur kartu dalam test.
  static const Key contentKey = PinnedBusCardBody.contentKey;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Pengisi transparan: memberi ukuran pada Stack saat ditempatkan
        // sebagai overlay (constraint loose dari Stack induk). Tidak menyerap
        // sentuhan karena tidak punya anak/warna.
        const SizedBox.expand(),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: PinnedBusCardBody(
            bus: bus,
            progress: progress,
            collapsed: collapsed,
            onTap: onTap,
            onClose: onClose,
            onCollapse: onCollapse,
            footer: footer,
            arrival: arrival,
          ),
        ),
      ],
    );
  }
}

/// Isi kartu bus tanpa pembungkus posisi (dipakai overlay [FloatingPinnedBusCard]
/// dan kartu bawah pada peta). Bergaya sama: latar tint koridor, garis aksen,
/// identitas bus, status halte saat ini & berikutnya, serta garis progres.
///
/// Bila [collapsed] benar hanya garis progres yang tampil. [footer] opsional
/// menambahkan rincian (mis. kecepatan & waktu pembaruan) pada mode penuh.
/// [onCollapse] menampilkan tombol "kecilkan" di samping tombol tutup, sehingga
/// kartu bisa kembali ke mode mini tanpa melepas pin bus.
class PinnedBusCardBody extends StatelessWidget {
  final Bus bus;
  final HalteProgress progress;
  final bool collapsed;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  /// Dipanggil saat tombol "kecilkan" ditekan (kembali ke mode mini). Null =
  /// tombol tidak ditampilkan — mis. pada kartu bus di peta yang tidak punya
  /// mode mini.
  final VoidCallback? onCollapse;
  final Widget? footer;

  /// Perkiraan kedatangan bus ke lokasi pengguna; pada mode mini ditampilkan
  /// sebagai chip "≈ N mnt" di kanan judul.
  final UserArrival? arrival;

  const PinnedBusCardBody({
    super.key,
    required this.bus,
    required this.progress,
    this.collapsed = false,
    this.onTap,
    this.onClose,
    this.onCollapse,
    this.footer,
    this.arrival,
  });

  /// Kunci untuk mengukur kartu dalam test.
  static const Key contentKey = ValueKey('floating_pinned_bus_card_content');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = corridorAccent(bus.corridor, theme);
    final onAccent = onColor(accent);

    // Jumlah tombol di sudut kanan-atas (kecilkan & tutup). Dipakai untuk
    // menyisakan ruang di header supaya judul tidak tertimpa.
    final buttonCount =
        (onCollapse != null ? 1 : 0) + (onClose != null ? 1 : 0);
    final headerReserve =
        collapsed ? 0.0 : buttonCount * _CardIconButton.extent;

    // Latar kartu: warna koridor bus, di-tint lembut agar tetap terasa "milik"
    // bus tersebut namun teks status tetap kontras.
    final background = corridorSurfaceTint(
      bus.corridor,
      theme,
      base: theme.colorScheme.surface,
      opacity: kCorridorPinnedTintOpacity,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          key: contentKey,
          padding: collapsed
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 6)
              : const EdgeInsets.fromLTRB(16, 8, 12, 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          // Tombol aksi ditempatkan sebagai overlay (bukan di dalam aliran
          // header) supaya tidak menambah tinggi baris header — mencegah
          // ruang kosong di bagian atas kartu. [AnimatedSize] default
          // meng-clip, jadi tombol harus berada di luar widget tersebut.
          child: Stack(
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: collapsed
                      ? [
                          _CompactHeader(
                            bus: bus,
                            accent: accent,
                            onAccent: onAccent,
                            arrival: arrival,
                          ),
                          const SizedBox(height: 8),
                          _ProgressTrack(progress: progress, accent: accent),
                          const SizedBox(height: 5),
                          _ProgressLabels(progress: progress, accent: accent),
                        ]
                      : [
                          _Header(
                            bus: bus,
                            accent: accent,
                            onAccent: onAccent,
                            trailingSpace: headerReserve,
                          ),
                          const SizedBox(height: 10),
                          _CurrentStatus(
                            step: progress.currentStep,
                            accent: accent,
                            onAccent: onAccent,
                          ),
                          const SizedBox(height: 10),
                          _NextStatus(
                            step: progress.nextStep,
                            bus: bus,
                            accent: accent,
                          ),
                          const SizedBox(height: 12),
                          _ProgressLine(progress: progress, accent: accent),
                          if (footer != null) ...[
                            const SizedBox(height: 12),
                            footer!,
                          ],
                        ],
                ),
              ),
              if (!collapsed && buttonCount > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // "Kecilkan" hanya muncul pada mode penuh, dan hanya bila
                      // pemanggil menyediakan jalannya (kartu pin di halaman).
                      if (onCollapse != null)
                        _CardIconButton(
                          icon: Icons.expand_more,
                          iconSize: 22,
                          semanticLabel: l10n.pinnedCardMinimize,
                          onTap: onCollapse!,
                        ),
                      if (onClose != null)
                        _CardIconButton(
                          icon: Icons.close,
                          semanticLabel: l10n.tooltipClose,
                          onTap: onClose!,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris rincian tambahan pada kartu bus: kecepatan real-time, tujuan yang
/// sedang ditempuh, dan waktu pembaruan data. Dipakai kartu peta dan kartu bus
/// yang di-pin agar tampil seragam (ala detail bus).
class PinnedBusCardFooter extends StatelessWidget {
  final Bus bus;

  /// Label terminus tujuan yang sedang ditempuh (mis. "RTH Imam Bonjol").
  final String? destinationLabel;

  /// Widget opsional di ujung kanan baris (mis. tombol ikuti/pin di kartu peta).
  final Widget? trailing;

  /// Perkiraan kedatangan bus ke lokasi pengguna (opsional).
  final UserArrival? arrival;

  const PinnedBusCardFooter({
    super.key,
    required this.bus,
    this.destinationLabel,
    this.trailing,
    this.arrival,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = corridorAccent(bus.corridor, theme);
    final speed = bus.speedKmh;
    final dest = destinationLabel?.trim();
    final estimate = arrival;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, thickness: 1, color: theme.dividerColor),
        const SizedBox(height: 10),
        Row(
          children: [
            if (speed != null && speed > 0) ...[
              BusSpeedDial(speedKmh: speed, color: accent),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (estimate != null) ...[
                    _ArrivalLine(arrival: estimate, accent: accent),
                    const SizedBox(height: 3),
                  ],
                  if (dest != null && dest.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 14, color: accent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            l10n.destinationLabel(dest),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.updatedLabel(
                      formatAge(bus.age(DateTime.now().toUtc()), l10n),
                    ),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
      ],
    );
  }
}

/// Baris "≈ N mnt ke lokasi Anda" pada footer kartu bus.
///
/// Dua kemungkinan isi, semuanya jujur terhadap data yang ada:
/// * bus praktis sudah di titik pengguna → "Bus di sekitar lokasi Anda";
/// * selain itu → estimasi menit + jarak garis lurus saat ini.
class _ArrivalLine extends StatelessWidget {
  final UserArrival arrival;
  final Color accent;

  const _ArrivalLine({required this.arrival, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final eta = arrival.etaMinutes;

    final String? text;
    if (arrival.isHere) {
      text = l10n.arrivalNear;
    } else if (eta != null) {
      text = '${l10n.arrivalEta(eta)} · ${formatDistance(arrival.distanceKm)}';
    } else {
      text = null;
    }
    if (text == null) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(Icons.near_me, size: 14, color: accent),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: accent, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Identitas ringkas pada mode mini: badge koridor + nomor bus, supaya konteks
/// bus tetap terbaca saat kartu diringkas (mis. saat menggulir).
class _CompactHeader extends StatelessWidget {
  final Bus bus;
  final Color accent;
  final Color onAccent;
  final UserArrival? arrival;

  const _CompactHeader({
    required this.bus,
    required this.accent,
    required this.onAccent,
    this.arrival,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estimate = arrival;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            bus.corridor.isEmpty ? '?' : bus.corridor,
            style: TextStyle(
              color: onAccent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            AppLocalizations.of(context).busLabel(bus.number),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        // Estimasi ke pengguna tetap terlihat walau kartu sedang ringkas:
        // inilah informasi yang dicari orang saat menunggu bus.
        if (estimate != null && estimate.hasEta) ...[
          const SizedBox(width: 8),
          _ArrivalChip(arrival: estimate, accent: accent),
        ],
      ],
    );
  }
}

/// Chip ringkas "≈ N mnt" / "sudah dekat" pada mode mini kartu bus.
class _ArrivalChip extends StatelessWidget {
  final UserArrival arrival;
  final Color accent;

  const _ArrivalChip({required this.arrival, required this.accent});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final eta = arrival.etaMinutes;
    final short =
        arrival.isHere ? l10n.arrivalHereShort : l10n.arrivalEtaShort(eta ?? 0);
    final spoken =
        arrival.isHere ? l10n.arrivalNear : l10n.arrivalEta(eta ?? 0);

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.14),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.near_me, size: 12, color: accent),
            const SizedBox(width: 3),
            Text(
              short,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris identitas: badge koridor dan nomor bus. Tombol aksi tidak di sini
/// agar tidak menambah tinggi baris (lihat [_CardIconButton]).
class _Header extends StatelessWidget {
  final Bus bus;
  final Color accent;
  final Color onAccent;

  /// Ruang kosong di kanan baris untuk tombol overlay (0, 44, atau 88 dp).
  final double trailingSpace;

  const _Header({
    required this.bus,
    required this.accent,
    required this.onAccent,
    this.trailingSpace = 44,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            bus.corridor.isEmpty ? '?' : bus.corridor,
            style: TextStyle(
              color: onAccent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            AppLocalizations.of(context).busLabel(bus.number),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        // Ruang cadangan agar judul tidak tertimpa tombol overlay di sudut
        // kanan-atas kartu.
        SizedBox(width: trailingSpace),
      ],
    );
  }
}

/// Tombol ikon di sudut kanan-atas kartu (kecilkan / tutup) dengan area sentuh
/// 48dp, ditempatkan sebagai overlay sehingga tidak memengaruhi tinggi baris
/// header.
///
/// Memakai [Semantics] dan bukan [Tooltip]: kartu ini juga hidup di atas
/// Navigator (`PinnedBusOverlay`), tempat `Tooltip` melempar
/// "No Overlay widget found".
class _CardIconButton extends StatelessWidget {
  /// Lebar yang disisakan tombol ini di baris header.
  static const double extent = 44;

  final IconData icon;
  final double iconSize;
  final String semanticLabel;
  final VoidCallback onTap;

  const _CardIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Status pertama: halte tempat bus berada saat ini.
class _CurrentStatus extends StatelessWidget {
  final HalteStep? step;
  final Color accent;
  final Color onAccent;

  const _CurrentStatus({
    this.step,
    required this.accent,
    required this.onAccent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = step?.halte.nama ?? l10n.notPassedHalte;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.my_location, size: 13, color: onAccent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.currentAt,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.3,
                  height: 1.1,
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Status kedua: halte berikutnya beserta jarak & estimasi waktu.
class _NextStatus extends StatelessWidget {
  final HalteStep? step;
  final Bus bus;
  final Color accent;

  const _NextStatus({this.step, required this.bus, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final s = step;
    final eta =
        s == null ? null : geo.estimateEtaMinutes(s.distanceKm, bus.speedKmh);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Icon(
            Icons.arrow_downward,
            size: 16,
            color: accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.nextHalte,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.3,
                  height: 1.1,
                ),
              ),
              if (s != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        s.halte.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${formatDistance(s.distanceKm)}'
                      '${eta != null ? l10n.etaSuffix(eta) : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  l10n.arrivedDestination,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Garis progres perjalanan bus sepanjang urutan halte arah yang ditempuh.
class _ProgressLine extends StatelessWidget {
  final HalteProgress progress;
  final Color accent;

  const _ProgressLine({required this.progress, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProgressTrack(progress: progress, accent: accent),
        const SizedBox(height: 5),
        _ProgressLabels(progress: progress, accent: accent),
      ],
    );
  }
}

/// Baris label asal / jumlah halte tersisa / tujuan pada garis progres.
class _ProgressLabels extends StatelessWidget {
  final HalteProgress progress;
  final Color accent;

  const _ProgressLabels({required this.progress, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final total = progress.steps.length;
    final idx = progress.currentIndex ?? progress.nextIndex;
    final remaining = (total - 1 - idx).clamp(0, total);

    return Row(
      children: [
        Expanded(
          child: Text(
            progress.originLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          remaining <= 0 ? l10n.lastHalte : l10n.halteRemaining(remaining),
          style: theme.textTheme.labelSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            progress.destinationLabel,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.1),
          ),
        ),
      ],
    );
  }
}

/// Rel & titik progres (dipakai mode penuh maupun mode ringkas). Titik posisi
/// bus memakai warna koridor bus yang di-pin ([accent]).
class _ProgressTrack extends StatelessWidget {
  final HalteProgress progress;
  final Color accent;

  const _ProgressTrack({required this.progress, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = progress.steps.length;
    final idx = progress.currentIndex ?? progress.nextIndex;
    final fraction = total <= 1 ? 0.0 : (idx / (total - 1)).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const dot = 10.0;
        final dotLeft = (width * fraction - dot / 2)
            .clamp(0.0, (width - dot).clamp(0.0, double.infinity));

        return SizedBox(
          height: dot,
          child: Stack(
            children: [
              // Rel dasar.
              Positioned(
                left: 0,
                right: 0,
                top: dot / 2 - 1.5,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Bagian yang sudah dilalui (warna koridor bus yang di-pin).
              Positioned(
                left: 0,
                top: dot / 2 - 1.5,
                child: Container(
                  height: 3,
                  width: width * fraction,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Titik posisi bus saat ini, berwarna koridor bus yang di-pin.
              Positioned(
                left: dotLeft,
                top: 0,
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
