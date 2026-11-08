# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users
Pengguna utama adalah pembuat aplikasi sendiri, seorang pengguna TransPadang di Padang yang ingin bepergian dengan transportasi umum. Ia membuka aplikasi saat akan atau sedang berangkat: mencari bus terdekat, memastikan kapan bus tiba, merencanakan rute antar koridor, dan memantau perjalanan. (Dikonfirmasi pengguna. Asumsi turunan, belum dikonfirmasi: situasi di luar ruangan, sering satu tangan, dengan sinyal yang tidak selalu stabil.)

## Product Purpose
TPLive adalah pelacak bus TransPadang (BRT Kota Padang) secara real-time untuk Android. Aplikasi menampilkan bus terdekat beserta jarak, ETA, dan tujuan, detail halte yang akan dilalui, perencana perjalanan (rute langsung atau satu kali transit), dan fitur "Ikuti bus" dengan notifikasi saat mendekati halte naik atau turun. Berhasil bila pengguna tahu kapan harus berangkat ke halte dan turun di halte yang benar tanpa menebak.

## Positioning
Memakai data posisi bus resmi TransPadang lewat WebSocket, ditambah perencana antar-koridor dan pemantauan perjalanan (naik/turun otomatis, dukungan jam Wear OS) yang tidak ada di aplikasi resmi. Tidak berafiliasi dengan TransPadang atau Pemerintah Kota Padang.

## Operating Context
Layanan beroperasi 06.00-19.00 WIB; di luar jam itu aplikasi menampilkan keadaan di luar jam operasional. Data halte dibundel di aplikasi (koridor K1-K6, tanpa REST). Server menukar lintang/bujur dan jam `last_update` berupa WIB yang disimpan sebagai UTC; keduanya sudah dinormalkan di kode. Bus dengan data lebih tua dari 5 menit disembunyikan.

## Capabilities and Constraints
- Android (Flutter 3.19.6 / Dart 3.3.4, Material 3, minSdk 21); web app dan jam Wear OS sebagai pendamping.
- Dua bahasa, Indonesia dan Inggris. Setiap string baru wajib ada di kedua berkas ARB.
- Warna koridor K1-K6 tetap sebagai identitas koridor.
- ETA adalah jarak garis lurus dibagi kecepatan, bukan ETA jalan raya; jangan disajikan seolah akurat di jaringan jalan.
- Konstanta gerak berada di `AppMotion`; gaya komponen di `app_theme.dart`.
- Belum diputuskan: standar aksesibilitas resmi dan target perangkat selain HP Android.

## Brand Commitments
- Penafian tidak resmi harus tetap jujur dan terlihat.
- Jam operasional 06.00-19.00 WIB harus ditampilkan apa adanya.
- Warna koridor K1-K6 dan label koridor dipertahankan.
- Seed warna merek `#F47F38`.

## Evidence on Hand
Aplikasi sudah dirilis (v1.4.0) dengan 248 tes otomatis dan landing page di `site/`. Tidak ada data pengguna, ulasan, atau metrik penggunaan; jangan mengarang testimoni atau angka.

## Product Principles
1. Utilitas lebih dulu: setiap layar menjawab "di mana bus saya dan kapan tiba".
2. Jujur tentang ketidakpastian: ETA perkiraan, data bisa basi, layanan ada jamnya.
3. Warna koridor berarti koridor; jangan dipakai sebagai hiasan.
4. Tenang dan cepat dibaca di luar ruangan, bukan ramai.
5. Hormati keputusan yang sudah disetel (peta, kartu pin, sheet) kecuali ada temuan nyata.

## Accessibility & Inclusion
Pengguna belum menetapkan standar khusus; acuan yang dipakai adalah praktik terbaik: kontras teks minimal 4.5:1, target sentuh minimal 48 dp, dukungan teks besar, mode gelap, `Semantics` pada kontrol ikon, dan penghormatan pada pengaturan "hapus animasi". Semua dalam dua bahasa.
