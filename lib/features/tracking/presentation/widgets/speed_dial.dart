import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'format.dart';

/// Lingkaran kecepatan ala speedometer: angka besar + satuan kecil "km/j".
/// Terisi warna koridor supaya mencolok dan langsung terbaca real-time.
/// Dipakai kartu rincian detail bus, kartu peta, dan kartu bus yang di-pin.
class BusSpeedDial extends StatelessWidget {
  final double speedKmh;
  final Color color;

  const BusSpeedDial({
    super.key,
    required this.speedKmh,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor2 = onColor(color);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${speedKmh.round()}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: onColor2,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          Text(
            AppLocalizations.of(context).speedUnit,
            style: theme.textTheme.labelSmall?.copyWith(
              color: onColor2,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
