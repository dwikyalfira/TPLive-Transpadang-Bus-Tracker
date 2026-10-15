import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/trans_ws_datasource.dart';

/// Penanda status di AppBar ("TPLive").
///
/// Menampilkan sebuah titik berwarna sesuai status, disertai keterangan
/// singkat yang tampil lalu menyusut menjadi titik saja. Transisi muncul/
/// menyusut memakai **simulasi pegas (SpringSimulation)** agar terasa natural:
/// saat muncul sedikit memantul, saat menyusut meredam tanpa berkedip.
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
        return (l10n.statusConnectedShort, const Color(0xFF2E7D32));
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

class _LiveStatusPillState extends State<LiveStatusPill>
    with SingleTickerProviderStateMixin {
  Timer? _hideTimer;

  /// Progres label: 0 = hanya titik (tersembunyi), 1 = label tampil penuh.
  late final AnimationController _label;

  /// Pegas saat label muncul — sedikit memantul. Overshoot ke atas dijinakkan
  /// oleh batas controller 0..1, jadi hasilnya tetap rapi.
  static const SpringDescription _showSpring =
      SpringDescription(mass: 1, stiffness: 600, damping: 34);

  /// Pegas saat label menyusut — teredam lebih besar agar tidak overshoot di
  /// bawah 0 (kalau overshoot, label akan muncul sekejap lagi = berkedip).
  static const SpringDescription _hideSpring =
      SpringDescription(mass: 1, stiffness: 480, damping: 46);

  @override
  void initState() {
    super.initState();
    _label = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: 1.0,
    );
    _scheduleHide();
  }

  @override
  void didUpdateWidget(LiveStatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _scheduleHide();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _animateLabel(1);
    // Hanya status "connected" (kondisi normal) yang menyembunyikan label
    // secara otomatis agar tidak mengganggu. Status lain (menunggu, menyambung,
    // menyambung ulang, di luar jam, terputus) adalah kondisi yang perlu
    // perhatian, sehingga labelnya dibiarkan tetap terlihat.
    if (!_shouldAutoHide(widget.status)) return;
    _hideTimer = Timer(LiveStatusPill.labelVisibleFor, () {
      if (mounted) _animateLabel(0);
    });
  }

  /// Apakah label boleh menyusut sendiri (auto-hide) untuk [status] ini.
  static bool _shouldAutoHide(ConnectionStatus? status) =>
      status == ConnectionStatus.connected;

  void _scheduleHideAfterTap() {
    _hideTimer?.cancel();
    _hideTimer = Timer(LiveStatusPill.tapLabelVisibleFor, () {
      if (mounted) _animateLabel(0);
    });
  }

  void _onTap() {
    _animateLabel(1);
    _scheduleHideAfterTap();
  }

  /// Menggerakkan label ke [target] (0 atau 1) memakai simulasi pegas, sehingga
  /// arah/kecepatannya menyambung mulus walau arah dibalik di tengah jalan.
  void _animateLabel(double target) {
    if (!_label.isAnimating && _label.value == target) return;
    final spring = target > _label.value ? _showSpring : _hideSpring;
    _label.animateWith(
      SpringSimulation(spring, _label.value, target, _label.velocity),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = LiveStatusPill.describe(
      widget.status,
      AppLocalizations.of(context),
    );

    final dot = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
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
          child: AnimatedBuilder(
            animation: _label,
            builder: (context, _) {
              final t = _label.value.clamp(0.0, 1.0);
              return Container(
                padding: EdgeInsets.lerp(
                  const EdgeInsets.all(6),
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  t,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10 + 0.02 * t),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    dot,
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: t,
                        heightFactor: t,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Opacity(
                            opacity: t,
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
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
