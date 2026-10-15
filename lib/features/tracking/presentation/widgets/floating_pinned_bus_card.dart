import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/bus_model.dart';
import '../../domain/geo_utils.dart' as geo;
import '../../domain/halte_tracker.dart';
import 'format.dart';

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

  const FloatingPinnedBusCard({
    super.key,
    required this.bus,
    required this.progress,
    this.collapsed = false,
    this.onTap,
    this.onClose,
  });

  /// Kunci untuk mengukur kartu dalam test.
  static const Key contentKey = ValueKey('floating_pinned_bus_card_content');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = corridorAccent(bus.corridor, theme);
    final onAccent = onColor(accent);

    // Latar kartu: warna koridor bus yang di-pin, di-tint lembut agar tetap
    // terasa "milik" bus tersebut namun teks hijau status tetap kontras.
    final background = corridorSurfaceTint(
      bus.corridor,
      theme,
      base: theme.colorScheme.surface,
      opacity: kCorridorPinnedTintOpacity,
    );

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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                key: FloatingPinnedBusCard.contentKey,
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
                // Tombol tutup ditempatkan sebagai overlay (bukan di dalam aliran
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
                                _ProgressTrack(
                                  progress: progress,
                                  accent: accent,
                                ),
                                const SizedBox(height: 5),
                                _ProgressLabels(
                                  progress: progress,
                                  accent: accent,
                                ),
                              ]
                            : [
                                _Header(
                                  bus: bus,
                                  accent: accent,
                                  onAccent: onAccent,
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
                                _ProgressLine(
                                  progress: progress,
                                  accent: accent,
                                ),
                              ],
                      ),
                    ),
                    if (!collapsed && onClose != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: _CloseButton(onClose: onClose!),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Baris identitas: badge koridor dan nomor bus. Tombol tutup tidak di sini
/// agar tidak menambah tinggi baris (lihat [_CloseButton]).
class _Header extends StatelessWidget {
  final Bus bus;
  final Color accent;
  final Color onAccent;

  const _Header({
    required this.bus,
    required this.accent,
    required this.onAccent,
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
        // Ruang cadangan agar judul tidak tertimpa tombol tutup overlay (48dp)
        // di sudut kanan-atas kartu.
        const SizedBox(width: 44),
      ],
    );
  }
}

/// Tombol tutup kartu dengan area sentuh 48dp, ditempatkan di sudut kanan-atas
/// kartu melalui overlay sehingga tidak memengaruhi tinggi baris header.
class _CloseButton extends StatelessWidget {
  final VoidCallback onClose;

  const _CloseButton({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).tooltipClose,
      child: InkResponse(
        onTap: onClose,
        radius: 24,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(
              Icons.close,
              size: 18,
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
    final eta = s == null
        ? null
        : geo.estimateEtaMinutes(s.distanceKm, bus.speedKmh);

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
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.1),
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
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.1),
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