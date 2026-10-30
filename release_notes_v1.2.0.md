## TransPadang Live v1.2.0

Perbaikan UX peta, estimasi waktu bus, dan splash mode gelap.

### Peta
- Filter koridor sekarang kapsul yang bisa dilipat; chevron berputar ke arah
  buka (samping), bukan atas-bawah.
- Tombol penyaring hanya panah (titik warna & label dihapus); koridor aktif
  tetap dibacakan oleh pembaca layar.
- Sheet halte pakai ikon papan keberangkatan (bukan ikon bus); tombol
  "Fokus ke bus" pindah ke kanan-bawah bersama tombol lokasi saya.

### Kartu bus ter-pin
- Menampilkan estimasi waktu (ETA) bus sampai ke lokasi pengguna.
- Tombol ciutkan (minimize) untuk kembali ke kartu mini tanpa melepas pin;
  estimasi tetap muncul saat berpindah dari kartu peta ke floating.

### Splash
- Splash layar Dart dihapus; aplikasi langsung ke Beranda (sudah punya
  indikator "Mendapatkan lokasi" & status live).
- Splash native mode gelap diperbaiki ke warna surface aplikasi (#201A17) —
  tidak ada lagi kilatan putih, dan tanpa kotak logo putih.

### Lainnya
- Akurasi data halte (timeline, tracker, pembaruan `assets/halte.json`).
- Mode peta & sumber bus tiruan (demo), skrip audit halte (dev-only).
- 214 tes lulus; `flutter analyze` bersih.

Catatan: APK ditandatangani dengan keystore debug (sesuai konfigurasi build
saat ini), cocok untuk instal langsung/sideload, bukan distribusi Play Store.
