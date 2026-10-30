import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/trans_ws_datasource.dart';

/// Penanda status di AppBar ("TPLive").
///
/// Menampilkan sebuah titik berwarna sesuai status, disertai keterangan
/// singkat. Keterangan **hanya** menyembunyikan diri otomatis pada status
/// normal [ConnectionStatus.connected]; status lain (menunggu, menyambung,
/// menyambung ulang, di luar jam, terputus) dibiarkan tetap tampil karena
/// butuh perhatian. Keterangan yang berakhiran "…" (menunggu/menyambung/
/// menyambung ulang) menampilkan titik-titik beranimasi.
///
/// Transisi muncul/menyusut memakai **simulasi pegas (SpringSimulation)** agar
/// terasa natural: saat muncul sedikit memantul, saat menyusut meredam tanpa
/// berkedip.
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

  static const TextStyle _labelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
  );

  @override
  void initState() {
    super.initState();
    _label = AnimationController(
      vsync: this,
      duration: AppMotion.long2,
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
    if (!_shouldAutoHide(widget.status)) return;
    _hideTimer = Timer(LiveStatusPill.labelVisibleFor, () {
      if (mounted) _animateLabel(0);
    });
  }

  /// Hanya status normal ([ConnectionStatus.connected]) yang boleh menyusut
  /// sendiri. Status connecting/disconnected (dan status perlu-perhatian lain)
  /// dibiarkan tetap tampil.
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
    final (rawLabel, color) = LiveStatusPill.describe(
      widget.status,
      AppLocalizations.of(context),
    );
    // Label berakhiran "…" menampilkan titik animasi; teks dasarnya dipisah
    // agar titik-titiknya bisa beranimasi (efek mengetik) tanpa mengubah teks.
    final hasEllipsis = rawLabel.endsWith('…');
    final baseLabel =
        hasEllipsis ? rawLabel.substring(0, rawLabel.length - 1) : rawLabel;

    final dot = AnimatedContainer(
      duration: AppMotion.medium2,
      curve: AppMotion.standard,
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    return GestureDetector(
      onTap: widget.onTap != null ? _onTap : null,
      child: Tooltip(
        message: rawLabel,
        child: Semantics(
          label: rawLabel,
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
                    Flexible(
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: t,
                          heightFactor: t,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Opacity(
                              opacity: t,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      baseLabel,
                                      softWrap: false,
                                      // Titik animasi digambar
                                      // [_AnimatedEllipsis]; jangan biarkan
                                      // Flutter menambahkan elipsisnya
                                      // sendiri agar titik tidak tampak dobel.
                                      overflow: TextOverflow.clip,
                                      style: _labelStyle.copyWith(color: color),
                                    ),
                                  ),
                                  if (hasEllipsis)
                                    _AnimatedEllipsis(
                                      style: _labelStyle.copyWith(color: color),
                                    ),
                                ],
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

/// Tiga titik yang tampil bergantian (efek mengetik) untuk label yang berakhir
/// "…". Ketiga titik selalu dirender (yang tersembunyi hanya transparan) supaya
/// lebar label tidak bergetar saat animasi berjalan. Titik sengaja tidak
/// fleksibel agar tidak ikut terhimpit saat ruang pill sempit — teks dasarnya
/// yang mengalah (dipotong) lebih dulu.
class _AnimatedEllipsis extends StatefulWidget {
  final TextStyle style;

  const _AnimatedEllipsis({required this.style});

  @override
  State<_AnimatedEllipsis> createState() => _AnimatedEllipsisState();
}

class _AnimatedEllipsisState extends State<_AnimatedEllipsis> {
  static const int _dots = 3;
  static const Duration _step = AppMotion.medium4;

  Timer? _timer;
  int _phase = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_step, (_) {
      if (!mounted) return;
      setState(() => _phase = _phase % _dots + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _dots; i++)
          Opacity(
            opacity: i < _phase ? 1.0 : 0.0,
            child: Text('.', softWrap: false, style: widget.style),
          ),
      ],
    );
  }
}
