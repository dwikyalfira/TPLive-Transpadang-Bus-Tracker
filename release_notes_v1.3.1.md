## TransPadang Live v1.3.1

Rilis perawatan: aksesibilitas, konsistensi tampilan Material 3, dan persiapan
proyek open source.

### Tampilan & aksesibilitas
- Penanda status di AppBar kini punya area sentuh 48 dp dan warna teks yang
  menyesuaikan tema terang/gelap agar kontrasnya terbaca.
- Ikon "di luar jam operasional" di beranda tidak lagi nyaris tak terlihat di
  tema gelap (warna ungu dipusatkan dengan varian gelap).
- Lingkaran kecepatan dan badge koridor tidak lagi terpotong saat ukuran font
  sistem diperbesar; kecepatan dibacakan sebagai satu label oleh pembaca layar.
- Tombol tutup kartu bus di peta diperbesar menjadi 48 dp.
- Kode koridor pada langkah rute kini 11sp (sebelumnya 9sp).
- Radius sudut disamakan dengan skala bentuk Material 3.

### Build & proyek
- APK rilis memakai R8 (minify + shrink resources).
- Keystore rilis kini opsional lewat `android/key.properties`.
- Menambah `LICENSE` (MIT), `CONTRIBUTING.md`, dan CI (analyze + test).
- `dart_defines.json` tidak lagi dilacak git; contoh token dikosongkan.

> APK ditandatangani kunci debug. Bila pemasangan sebagai pembaruan gagal
> ("signature mismatch"), copot versi lama lebih dulu.
