import 'package:flutter/material.dart';

import 'format.dart';

/// Badge koridor bulat yang seragam (warna koridor + teks kode kontras).
/// Menggantikan beberapa salinan serupa di kartu bus, hasil rute, dan
/// pemilih lokasi.
class CorridorBadge extends StatelessWidget {
  final String corridor;

  /// Diameter lingkaran.
  final double size;

  /// Ukuran teks; bila null diturunkan dari [size].
  final double? fontSize;

  const CorridorBadge({
    super.key,
    required this.corridor,
    this.size = 44,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final color = corridorAccent(corridor, Theme.of(context));
    final label = corridor.isEmpty ? '?' : corridor;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        label,
        style: TextStyle(
          color: onColor(color),
          fontWeight: FontWeight.bold,
          fontSize: fontSize ?? (size * 0.34),
        ),
      ),
    );
  }
}

/// Label tepi (Awal/Akhir/Naik/Turun) untuk daftar halte & timeline.
///
/// Bila [filled] benar, pill terisi penuh warna ([color]); bila tidak, pill
/// memakai latar transparan tipis (lebih samar) — dipakai untuk menandai
/// terminus agar tidak bersaing dengan penanda naik/turun pengguna.
class EdgeBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;

  const EdgeBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = filled ? onColor(color) : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: filled ? color : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: foreground),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
