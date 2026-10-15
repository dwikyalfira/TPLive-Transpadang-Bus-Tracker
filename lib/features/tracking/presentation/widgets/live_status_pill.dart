import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/trans_ws_datasource.dart';

/// Penanda status "live" aplikasi di AppBar.
///
/// Lima status dengan warna berbeda:
/// - hijau  = live (terhubung ke sumber data)
/// - kuning = menyambung / menyambung ulang
/// - merah  = tidak terhubung
/// - ungu   = layanan tidak tersedia / bus tidak melayani (di luar jam operasi)
///
/// [onTap] dipanggil saat pengguna menekan pill. Ketika ditekan, keterangan
/// akan tampil dan akan menyembunyikan diri setelah durasi `tapLabelVisibleFor`.
/// Jika null, tindakan tap tidak diaktifkan.
class LiveStatusPill extends StatefulWidget {
  final ConnectionStatus? status;
  final VoidCallback? onTap;

  const LiveStatusPill({super.key, this.status, this.onTap});

  /// Berapa lama label deskripsi tampil sebelum menyusut menjadi dot saja
  /// saat aplikasi start/diupdate (tanpa interaksi user).
  static const Duration labelVisibleFor = Duration(seconds: 3);

  /// Berapa lama label deskripsi tampil setelah pengguna menekan pill.
  static const Duration tapLabelVisibleFor = Duration(seconds: 3);

  /// (label, warna) untuk status saat ini.
  static (String, Color) describe(
    ConnectionStatus? status,
    AppLocalizations l10n,
  ) {
    switch (status) {
      case ConnectionStatus.connected:
        return (l10n.statusLive, const Color(0xFF2E7D32));
      case ConnectionStatus.connecting:
        return (l10n.statusConnecting, const Color(0xFFF9A825));
      case ConnectionStatus.reconnecting:
        return (l10n.statusReconnecting, const Color(0xFFF9A825));
      case ConnectionStatus.outsideHours:
        return (l10n.statusOutsideHoursShort, const Color(0xFF7B1FA2));
      case ConnectionStatus.disconnected:
        return (l10n.statusPillDisconnected, const Color(0xFFC62828));
      case null:
        return (l10n.statusWaiting, const Color(0xFF9E9E9E));
    }
  }

  @override
  State<LiveStatusPill> createState() => _LiveStatusPillState();
}

class _LiveStatusPillState extends State<LiveStatusPill> {
  Timer? _hideTimer;
  bool _showLabel = true;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(LiveStatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      setState(() => _showLabel = true);
      _scheduleHide();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(LiveStatusPill.labelVisibleFor, () {
      if (mounted) setState(() => _showLabel = false);
    });
  }

  void _scheduleHideAfterTap() {
    _hideTimer?.cancel();
    _hideTimer = Timer(LiveStatusPill.tapLabelVisibleFor, () {
      if (mounted) setState(() => _showLabel = false);
    });
  }

  void _onTap() {
    setState(() => _showLabel = true);
    _scheduleHideAfterTap();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = LiveStatusPill.describe(
      widget.status,
      AppLocalizations.of(context),
    );

    const anim = Duration(milliseconds: 350);
    const curve = Curves.easeInOut;

    final dot = AnimatedContainer(
      duration: anim,
      curve: curve,
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    return GestureDetector(
      onTap: widget.onTap != null ? _onTap : null,
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          child: AnimatedContainer(
            duration: anim,
            curve: curve,
            padding: _showLabel
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
                : const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(_showLabel ? 0.12 : 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                dot,
                ClipRect(
                  child: AnimatedAlign(
                    duration: anim,
                    curve: curve,
                    alignment: Alignment.centerLeft,
                    widthFactor: _showLabel ? 1.0 : 0.0,
                    heightFactor: _showLabel ? 1.0 : 0.0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
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