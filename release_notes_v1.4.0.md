## TransPadang Live v1.4.0

Fitur baru untuk perjalanan (deteksi naik/turun otomatis dan app Wear OS), plus
gestur sheet yang lebih mengikuti jari dan perbaikan tampilan.

### Fitur baru
- **Deteksi naik/turun otomatis**: saat "Ikuti bus" aktif, aplikasi mengenali
  kapan Anda naik dan turun. Opsi "berhenti ikuti otomatis" menghentikan
  pelacakan setelah turun (aktif secara bawaan).
- **App Wear OS**: menampilkan bus yang di-pin di jam (peta, ikuti bus, ETA
  bus ke Anda, live bar). Dipasang dari Pengaturan → Smartwatch lewat wireless
  debugging.
- **Onboarding** 3 layar beranimasi untuk pemakaian pertama, bisa dibuka lagi
  dari Pengaturan.
- Ikon aplikasi baru bergaya gradasi.
- Label di luar jam operasional kini "Tidak beroperasi" / "Not running".

### Gestur & gerak
- Sheet detail bus: saat header dilepas, sheet bergerak dengan pegas yang
  meneruskan kecepatan jari. Swipe cepat menutup, tarikan pelan kembali ke
  posisi penuh, dan sheet bisa ditangkap lagi di tengah animasi.
- Menarik header ke atas melewati batas kini menahan (rubber-band) alih-alih
  berhenti mendadak, disertai getar halus saat melewati titik tutup.
- Hasil rencana perjalanan bertukar dengan fade singkat, tidak lagi muncul
  mendadak. Semua gerak menghormati pengaturan "hapus animasi".

### Tampilan & aksesibilitas
- Area sentuh penanda bus di peta menjadi 48 dp.
- Bintang favorit dan penanda tujuan memakai warna tema, bukan warna koridor
  (warna koridor hanya berarti koridor).
- Hijau "berhasil" di layar Wear punya varian untuk tema gelap.
- Kartu "Lihat panduan lagi" di Pengaturan tidak lagi menempel ke kartu di
  atasnya.
- Peta HP: bus yang di-pin tetap di tengah dan bergerak mulus.

### Build & proyek
- Build debug kembali berjalan: R8/D8 dipasang ke 8.2.47 di
  `android/settings.gradle` (D8 bawaan AGP 7.3.0 crash saat mem-dex
  `libadb-android` dan `spake2-android`).
- Menambah `PRODUCT.md` (konteks produk untuk pekerjaan desain).

> APK ditandatangani kunci debug. Bila pemasangan sebagai pembaruan gagal
> ("signature mismatch"), copot versi lama lebih dulu.
