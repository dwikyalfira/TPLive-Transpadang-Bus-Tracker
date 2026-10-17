import 'package:flutter/material.dart';

import 'format.dart';

/// Palet warna satu koridor untuk [CorridorIconButton].
///
/// Dihitung sekali (mis. di [CorridorPalette.of]) lalu dipakai ulang agar
/// perhitungan kontras warna yang relatif mahal tidak diulang tiap frame saat
/// sorotan dianimasikan.
class CorridorPalette {
  final Color accent;
  final Color mutedAccent;
  final Color mutedFg;
  final Color litFg;
  final Color borderColor;

  const CorridorPalette({
    required this.accent,
    required this.mutedAccent,
    required this.mutedFg,
    required this.litFg,
    required this.borderColor,
  });

  factory CorridorPalette.of(String corridor, ThemeData theme) {
    final base = corridorAccent(corridor, theme);
    final muted = base.withOpacity(0.35);
    final mutedBg = Color.alphaBlend(muted, theme.colorScheme.surface);
    return CorridorPalette(
      accent: base,
      mutedAccent: muted,
      mutedFg: corridorOnBackground(corridor, mutedBg),
      litFg: onCorridorColor(corridor),
      borderColor: theme.colorScheme.primary,
    );
  }
}

/// Tombol ikon koridor bulat (dipakai baris pemilih koridor di layar utama &
/// layar peta).
///
/// Sorotan diatur [selFactor] (0 = redup, 1 = menyala) sehingga pemanggil bisa
/// menganimasikannya (mis. menyusur geseran tab) atau memberikannya langsung.
/// Area sentuh 48dp, lingkaran visual 40dp.
class CorridorIconButton extends StatelessWidget {
  final String corridor;
  final CorridorPalette palette;
  final double selFactor;
  final VoidCallback onTap;

  const CorridorIconButton({
    super.key,
    required this.corridor,
    required this.palette,
    required this.selFactor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = selFactor.clamp(0.0, 1.0);
    final bg = Color.lerp(palette.mutedAccent, palette.accent, t)!;
    final fg = Color.lerp(palette.mutedFg, palette.litFg, t)!;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Transform.scale(
              scale: 1 + 0.06 * t,
              child: Container(
                // Sorotan sudah digerakkan [selFactor]; pakai Container biasa
                // (bukan AnimatedContainer) agar tidak memicu animasi implisit
                // tambahan saat pemanggil menganimasikan tiap frame.
                constraints:
                    const BoxConstraints.tightFor(width: 40, height: 40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.borderColor.withOpacity(t),
                    width: 2 * t,
                  ),
                ),
                child: Text(
                  corridor,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
