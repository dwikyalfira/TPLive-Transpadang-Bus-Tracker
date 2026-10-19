import 'package:flutter/material.dart';

/// Menutup bottom sheet berjenjang saat sheet ditarik turun sampai tinggi
/// minimum.
///
/// [DraggableScrollableSheet] hanya mengecilkan tingginya; route modal tidak
/// selalu ikut tertutup karena Flutter membandingkan `extent` dengan
/// `minExtent` secara persis. Saat berhenti, nilainya bisa berupa pecahan
/// sangat kecil (mis. `0.0000001`), sehingga pengecekan itu gagal dan scrim
/// gelap tertinggal sampai pengguna mengetuknya. Listener ini memakai
/// toleransi dan menutup route satu kali saja.
class CloseOnMinExtent extends StatefulWidget {
  final Widget child;

  /// Selisih maksimum dari [DraggableScrollableNotification.minExtent] yang
  /// masih dianggap "tertutup".
  final double tolerance;

  const CloseOnMinExtent({
    super.key,
    required this.child,
    this.tolerance = 0.001,
  });

  @override
  State<CloseOnMinExtent> createState() => _CloseOnMinExtentState();
}

class _CloseOnMinExtentState extends State<CloseOnMinExtent> {
  bool _popped = false;

  bool _onNotification(DraggableScrollableNotification notification) {
    if (_popped) return false;
    if (notification.extent > notification.minExtent + widget.tolerance) {
      return false;
    }
    _popped = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Route bisa saja sudah ditutup oleh penanganan bawaan Flutter pada
      // frame yang sama; jangan pop lagi agar halaman di bawahnya tidak ikut
      // tertutup.
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
      Navigator.of(context).maybePop();
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: _onNotification,
      child: widget.child,
    );
  }
}
