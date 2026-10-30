## TransPadang Live v1.3.0

Kartu status peta yang bisa dilipat, animasi yang lebih halus, dan pembersihan
token gerak di seluruh aplikasi.

### Peta
- Kartu "sedang tidak melayani penumpang" dipindah tepat di bawah filter
  koridor, rata kiri, dengan lebar maksimum 520 dp agar tidak melebar di
  tablet.
- Kartu bisa dilipat: saat tertutup hanya menyisakan ikon bulan 48 dp (ukuran
  sama dengan tombol filter koridor di atasnya), dan mengetuk ikon itu
  menampilkan teks penuh lagi.
- Kartu otomatis melipat saat peta digeser, di-pinch, atau diketuk — jadi tidak
  lagi menutupi peta saat pengguna sedang menjelajah.
- Mengetuk area teks kartu tidak menutupnya (hanya ikon dan gestur peta yang
  memicu lipat).

### Animasi
- Komponen baru `RevealRow`: kotak dan isinya dianimasikan dari satu
  controller, sehingga teks muncul sambil melebar — bukan "pop" seperti
  `AnimatedSize`.
- Filter koridor dan kartu status memakai durasi serta kurva Material 3 yang
  identik, jadi keduanya terasa satu keluarga.
- Kartu bus ter-pin sekarang memudar + meluncur naik saat di-pin, dan memudar
  keluar saat pin dilepas (bukan hilang mendadak).
- Indikator progres perjalanan bus ter-pin dianimasikan halus saat posisi bus
  diperbarui.
- Tampilan kosong/memuat/galat mendapat animasi masuk memudar + naik 10 dp.
- Semua animasi menghormati preferensi aksesibilitas "hapus animasi"
  (`MediaQueryData.disableAnimations`).

### Konsistensi tema
- `AppMotion` diperluas (`short1`, `linear`, `resolve`) dan durasi yang masih
  di-hardcode di layar peta, pemilih lokasi, dan rencana perjalanan diganti ke
  token yang sama.
- `MaterialApp` memakai durasi & kurva transisi tema yang eksplisit, jadi
  pergantian terang/gelap tidak memakai nilai bawaan framework.

### Pengaturan
- Tanda tangan `@dwikyalfira` di kaki halaman (rata kiri, opasitas 60%).

### Data halte
- Audit koordinat K3 diperbarui: 94 halte diperiksa, 16 koordinat dikoreksi
  (≥ 3 m), 3 halte ditandai perlu cek lapangan; `assets/halte.json`,
  `corridor_routes.json`, dan `tools/halte_audit.csv` diselaraskan.
- Skrip baru `scripts/import_halte_txt.py` dan `scripts/fix_halte_coords.py`
  untuk memasukkan data halte dari teks lapangan dan merapikan koordinat.

### Kualitas
- 224 tes lulus (naik dari 214), termasuk tes geometri kartu status, paritas
  durasi/kurva antara filter dan kartu, animasi setengah jalan, serta semantik
  saat kartu tertutup.
- `flutter analyze` bersih.

Catatan: APK ditandatangani dengan keystore debug (sesuai konfigurasi build
saat ini), cocok untuk instal langsung/sideload, bukan distribusi Play Store.
