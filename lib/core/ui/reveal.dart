import 'package:flutter/widgets.dart';

import '../theme/app_motion.dart';

/// Baris [leading] + area tambahan yang bisa dibuka/ditutup dengan animasi
/// halus (lebar — dan opsional tinggi — dianimasikan dari tepi kiri sambil
/// isinya memudar & bergeser sedikit masuk).
///
/// Kenapa bukan [AnimatedSize]/[AnimatedCrossFade]: keduanya hanya
/// menganimasikan kotaknya, sedangkan isi area muncul/menghilang seketika —
/// hasilnya isi terlihat "pop" di ujung animasi. Di sini isi dan kotaknya
/// memakai satu animation controller yang sama, jadi pembukaan terasa seperti
/// tirai yang tersingkap dan penutupan seperti tirai yang menutup.
///
/// Isi area hanya dibangun selama terbuka atau selama animasi menutup masih
/// berjalan; begitu tertutup penuh isinya dilepas dari pohon. Dengan begitu isi
/// yang tersembunyi tidak ikut tertangkap pembaca layar, tidak bisa disentuh,
/// dan tidak ditemukan `find.*` pada pengujian.
class RevealRow extends StatefulWidget {
  const RevealRow({
    super.key,
    required this.open,
    required this.leading,
    required this.child,
    this.revealHeight = false,
    this.duration = AppMotion.medium1,
    this.curve = AppMotion.emphasizedDecelerate,
    this.reverseCurve = AppMotion.emphasizedAccelerate,
  });

  /// `true` = area tambahan terbuka penuh, `false` = menutup jadi [leading].
  final bool open;

  /// Bagian yang selalu tampil (mis. tombol ikon 48 dp).
  final Widget leading;

  /// Isi area tambahan. Selalu diberi lebar sisa ruang penuh, lalu dipotong
  /// mengikuti animasi.
  final Widget child;

  /// Ikut menganimasikan tinggi isi. Pakai `true` bila tinggi wadah mengikuti
  /// isi (mis. kartu dua baris); biarkan `false` bila tinggi wadah sudah tetap
  /// (mis. kapsul 48 dp) agar isinya tidak ikut terpotong vertikal.
  final bool revealHeight;

  /// Durasi buka/tutup (dihormati [AppMotion.resolve] → "hapus animasi").
  final Duration duration;

  /// Kurva saat membuka.
  final Curve curve;

  /// Kurva saat menutup.
  final Curve reverseCurve;

  @override
  State<RevealRow> createState() => _RevealRowState();
}

class _RevealRowState extends State<RevealRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.open ? 1 : 0,
  );

  /// Skala buka/tutup untuk lebar & tinggi area.
  late final Animation<double> _size = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
    reverseCurve: widget.reverseCurve,
  );

  /// Isi baru memudar masuk lebih dulu daripada kotaknya melebar, dan sudah
  /// memudar habis saat kotak hampir tertutup — jadi isi tidak pernah "menempel"
  /// di kotak yang masih sempit, dan saat menutup teks tetap terlihat sampai
  /// kotaknya benar-benar menyusut (terpotong seperti tirai), bukan hilang di
  /// awal animasi.
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.05, 0.55, curve: Curves.easeOut),
  );

  /// Geseran halus dari kiri, searah dengan arah tersingkapnya area.
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(-0.04, 0),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = AppMotion.resolve(context, widget.duration);
  }

  @override
  void didUpdateWidget(RevealRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open == widget.open) return;
    if (widget.open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Selama menutup, isi tetap dibangun sampai animasinya selesai supaya
        // bisa memudar; setelah value 0 isi dilepas.
        final showChild = widget.open || _controller.value > 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.leading,
            if (showChild)
              Flexible(
                child: ClipRect(
                  child: Align(
                    // Tumbuh dari tepi kiri (dan dari tengah secara vertikal),
                    // jadi area terlihat "tersingkap", bukan melompat.
                    alignment: Alignment.centerLeft,
                    widthFactor: _size.value,
                    heightFactor: widget.revealHeight ? _size.value : 1,
                    child: FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: SizedBox(
                          width: double.infinity,
                          child: ExcludeSemantics(
                            excluding: !widget.open,
                            child: IgnorePointer(
                              ignoring: !widget.open,
                              child: widget.child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
