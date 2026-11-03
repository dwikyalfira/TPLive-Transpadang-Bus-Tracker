# Berkontribusi ke TPLive

Terima kasih sudah tertarik! Panduan singkat:

## Persiapan
- Flutter **3.19.6** / Dart **3.3.4** (versi terkunci; API yang lebih baru
  merusak build — lihat daftar yang dilarang di `AGENTS.md`).
- `flutter pub get`
- Token Mapbox **opsional**. Tanpa token, peta dan geocoding otomatis memakai
  OpenStreetMap/Nominatim. Bila ingin memakai token sendiri:
  `copy dart_defines.example.json dart_defines.json` lalu isi `MAPBOX_TOKEN`
  (berkas itu di-gitignore; jangan di-commit).

## Menjalankan tanpa menunggu bus sungguhan
Server resmi hanya mengirim data pada 06:00–19:00 WIB. Untuk demo/pengembangan:

```bash
flutter run --dart-define=MOCK_BUS=true
```

## Sebelum membuka pull request
- `flutter analyze` harus **0 issue**.
- `flutter test` harus lulus (CI menjalankan keduanya).
- Teks UI baru ditambahkan ke **dua** berkas: `lib/l10n/app_id.arb` (template)
  dan `lib/l10n/app_en.arb`, lalu jalankan `flutter gen-l10n` dan sertakan
  hasil generate-nya.
- Gaya komponen ditaruh di `lib/core/theme/app_theme.dart`; durasi/kurva animasi
  di `AppMotion`. Hindari warna, radius, dan ukuran font yang di-hardcode.

Rincian arsitektur dan jebakan umum ada di `AGENTS.md` dan `README.md`.
