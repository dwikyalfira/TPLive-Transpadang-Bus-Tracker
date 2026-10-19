# TPLive — TransPadang Bus Tracker

Aplikasi pelacak bus **TransPadang** (Bus Rapid Transit Kota Padang) secara *real-time*.
Dibangun dengan **Flutter** (Material 3) untuk Android, memakai data posisi resmi
TransPadang melalui **WebSocket** serta perencana perjalanan antar koridor.

An open-source **real-time TransPadang bus tracker** for the city of Padang (Indonesia),
built with **Flutter** (Material 3) for Android. It consumes the official TransPadang
bus positions over **WebSocket** and includes a multi-corridor trip planner.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.3.4-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://www.android.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](#lisensi)

> **Navigasi bahasa / Language navigation:**
> [Bahasa Indonesia](#bahasa-indonesia) · [English](#english)

---

## Bahasa Indonesia

### Daftar Isi

- [Tentang Aplikasi](#tentang-aplikasi)
- [Fitur](#fitur)
- [API yang Digunakan](#api-yang-digunakan)
- [Arsitektur & Teknologi](#arsitektur--teknologi)
- [Struktur Proyek](#struktur-proyek)
- [Cara Menjalankan](#cara-menjalankan)
- [Catatan Teknis](#catatan-teknis)
- [Lisensi](#lisensi)

### Tentang Aplikasi

**TPLive** adalah aplikasi Android untuk memantau posisi bus TransPadang secara
langsung (*live*). Aplikasi menampilkan daftar bus terdekat dari lokasi pengguna
beserta jarak, estimasi waktu kedatangan (ETA), tujuan, kecepatan, dan arah bus.
Pengguna dapat memfilter per koridor (K1–K6), melihat detail halte yang akan dilalui,
serta **mengikuti** satu bus — aplikasi akan mengirim notifikasi saat bus hampir tiba
di halte naik dan halte turun.

Selain pelacakan, tersedia **perencana perjalanan** yang menghitung rute TransPadang
dari titik asal ke tujuan, termasuk opsi **langsung** maupun **1 kali transit**
(pindah koridor), lengkap dengan estimasi waktu tempuh dan waktu jalan kaki.

> **Penafian:** TPLive **bukan aplikasi resmi TransPadang** dan **tidak memiliki
> afiliasi** apa pun dengan TransPadang maupun Pemerintah Kota Padang. Aplikasi ini
> dibuat murni untuk memudahkan pengguna TransPadang dalam memantau bus dan
> merencanakan perjalanan.

### Fitur

- **Peta daftar bus real-time** — daftar bus terdekat, diurutkan berdasarkan jarak,
  dengan jarak, ETA, tujuan, dan umur data (*freshness*).
- **Filter per koridor** — tab "Semua" serta chip koridor K1–K6 dengan warna khas
  tiap koridor.
- **Detail bus & timeline halte** — bottom sheet menampilkan posisi bus pada urutan
  halte, halte saat ini & berikutnya, kecepatan (dial speedometer), jarak, ETA, dan
  progress bar perjalanan.
- **Ikuti bus (*follow*)** — foreground service Android menampilkan notifikasi
  berjalan berisi halte berikutnya, jarak, ETA, dan progress. Di Android 16+ tampil
  sebagai *live update* (`Notification.ProgressStyle`).
- **Notifikasi kedatangan** — pemberitahuan saat bus tinggal 1–2 halte dari halte
  naik/turun, dan saat tiba di halte naik/turun.
- **Perencana perjalanan** — rute langsung + maksimal 1 transit, mendukung transit
  "nama halte sama" maupun transfer jalan kaki singkat antar halte berdekatan.
- **Pencarian tujuan** — pilih tujuan melalui **halte** TransPadang atau cari
  **tempat** (POI) memakai Nominatim/OSM.
- **Kartu bus melayang (*pinned card*)** — kartu "update island" yang tetap terlihat
  di semua halaman; mengecil saat menggulir dan melar saat diketuk.
- **Material You (dynamic color)** — tema mengikuti warna wallpaper (Android 12+),
  plus mode terang/gelap/sistem.
- **Dua bahasa** — Bahasa Indonesia dan English, dapat mengikuti bahasa sistem.
- **Jam operasional** — status khusus "layanan tidak tersedia" di luar jam 06.00–19.00 WIB.

### API yang Digunakan

Aplikasi memakai **dua jalur API**, ditambah layanan geocoding pihak ketiga.

#### 1. WebSocket Realtime — Posisi Bus

| Item | Nilai |
|---|---|
| Endpoint | `wss://wstrans.padang.go.id/ws` |
| Autentikasi | Tidak perlu |
| Data | Posisi, kecepatan, arah, dan rute semua bus |
| Interval | Snapshot penuh dikirim ulang tiap ±1–2 detik |

**Alur:**

1. Klien membuka koneksi WebSocket. Server menyapa:
   ```json
   {"type": "info", "message": "Connected to Trans-Api WebSocket"}
   ```
2. Klien berlangganan semua bus:
   ```json
   {"type": "subscribeAll"}
   ```
3. Server mengirim snapshot berulang:
   ```json
   {
     "type": "allBusLocation",
     "data": [
       {
         "bus": "65",
         "longitude": "-0.8982466666666666",
         "latitude": "100.38608888888889",
         "corridor": "K3",
         "last_update": "2026-10-12 14:32:20",
         "direct": "109",
         "route": "RTH Imam Bonjol Ruas Hasanuddin - Pusat Pemerintahan Balai Kota Padang",
         "speed": "32"
       }
     ]
   }
   ```

**Skema field per bus:**

| Field | Tipe | Keterangan |
|---|---|---|
| `bus` | string | Nomor/ID bus (mis. `"65"`) |
| `longitude` | string | **Sebenarnya LATITUDE** (server mengirim terbalik) |
| `latitude` | string | **Sebenarnya LONGITUDE** (server mengirim terbalik) |
| `corridor` | string | Kode koridor: `K1`…`K6` |
| `route` | string | Nama rute koridor |
| `direct` | string | Arah/heading (derajat, 0–360) |
| `speed` | string | Kecepatan (km/jam) |
| `last_update` | string | Timestamp **WIB (UTC+7)**, format `yyyy-MM-dd HH:mm:ss` |

**Catatan penting:**

- Field `latitude` dan `longitude` **terbalik**. Normalisasi: `lat = json["longitude"]`,
  `lng = json["latitude"]` (lihat `lib/features/tracking/data/bus_model.dart`).
- `last_update` memakai waktu **WIB**, dikonversi ke UTC dengan mengurangi 7 jam.
- Jam operasional bus: **06.00–19.00 WIB**. Di luar jam itu bus tidak beroperasi.
- Layanan native juga memakai langganan per koridor: `{"type":"subscribeKoridor","koridor":"K3"}`,
  yang membalas dengan `busLocationByKoridor`.

#### 2. REST — api-superapp (TransPadang)

Base URL: `https://api-superapp.padang.go.id/trans-padang/`

| Method | Path | Deskripsi |
|---|---|---|
| `GET` | `/trans-padang/` | Base / index |
| `GET` | `/trans-padang/api/booklet` | Booklet koridor (info rute & jadwal) |
| `GET` | `/trans-padang/api/dinas/?perPage=2000` | Daftar dinas/operator |
| `GET` | `/trans-padang/api/kontak` | Kontak / WhatsApp |

> **Catatan:** endpoint REST ini dipakai aplikasi resmi "Padang Mobile" dan saat diakses
> publik langsung membalas **HTTP 429 Too Many Requests** (kemungkinan perlu token/rate-limit
> per IP). Versi TPLive ini **tidak bergantung** pada REST: dataset halte dikemas lokal
> (`assets/halte.json`), sementara posisi bus murni dari WebSocket.

#### 3. Geocoding — Nominatim (OpenStreetMap)

| Item | Nilai |
|---|---|
| Host | `nominatim.openstreetmap.org` |
| Kegunaan | Pencarian tempat (POI) saat memilih tujuan |
| Batas wilayah | Viewbox sekitar Padang, `bounded=1`, `countrycodes=id` |
| Bahasa | `id` |

Sesuai kebijakan Nominatim, aplikasi memakai User-Agent yang jelas dan tidak
melakukan panggilan berlebihan.

### Arsitektur & Teknologi

**Stack:**

- **Flutter** (Dart SDK `>=3.3.4 <4.0.0`), Material 3.
- **flutter_riverpod** — state management.
- **web_socket_channel** — koneksi WebSocket realtime.
- **geolocator** — lokasi GPS perangkat.
- **latlong2** — matematika geo (Haversine, bearing, proyeksi segmen).
- **shared_preferences** — preferensi tema/bahasa yang persisten.
- **intl** + **flutter_localizations** — lokalisasi (ARB → kelas ter-generate).
- **dynamic_color** — Material You (warna mengikuti wallpaper Android 12+).
- **okhttp3** (Android native) — WebSocket pada foreground service.

**Pola arsitektur** per fitur: `data` → `domain` → `presentation`.

- `TransWsDataSource` menangani satu koneksi, **auto-reconnect** dengan
  *exponential backoff + jitter*, langganan `subscribeAll`, dan jeda saat aplikasi
  masuk latar belakang.
- `HalteTracker` memetakan posisi bus ke urutan halte koridornya, menentukan arah
  (`pergi`/`pulang`), halte saat ini & berikutnya, serta terminus asal/tujuan.
- `HeadingTracker` memperkirakan arah gerak nyata dari riwayat posisi (vector sum
  berbobot jarak) karena field `direct` dari server kadang bising.
- `TripPlanner` menghitung rute langsung + maksimal 1 transit beserta penalti waktu
  dan jarak jalan kaki.
- `FollowAlertEngine` menentukan kapan notifikasi "mendekat" / "saatnya naik/turun"
  dikirim (murni, tanpa I/O).

**Layanan native Android** (`android/app/src/main/kotlin/.../`):

- `FollowService.kt` — foreground service (`dataSync`) yang membuka WebSocket sendiri
  (OkHttp), berlangganan satu koridor, lalu memperbarui notifikasi ongoing. Berhenti
  otomatis bila data bus basi > 5 menit.
- `MainActivity.kt` — `MethodChannel` `id.dwiky.transpadang_live/follow`
  (`startFollow`, `stopFollow`, `isFollowing`, `getFollowed`,
  `requestNotificationPermission`, `showEventNotification`).
- `HalteMath.kt` — perhitungan progress halte & ETA di sisi native.

### Struktur Proyek

```
transpadang_live/
├── android/                     # Proyek Android (Kotlin native service)
│   └── app/src/main/kotlin/id/dwiky/transpadang_live/
│       ├── MainActivity.kt      # MethodChannel + notifikasi acara
│       ├── FollowService.kt     # Foreground service "ikuti bus"
│       └── HalteMath.kt         # Matematika halte/ETA sisi native
├── assets/
│   ├── halte.json               # Dataset halte per koridor (2 arah)
│   └── logo/                    # Ikon & splash
├── lib/
│   ├── core/
│   │   ├── app_navigator.dart   # Navigator global key + observer
│   │   ├── config.dart          # Konfigurasi terpusat (URL, jam operasional)
│   │   ├── follow_service.dart  # Pembungkus MethodChannel (follow)
│   │   └── settings.dart        # Preferensi tema/bahasa (SharedPreferences)
│   ├── features/
│   │   ├── splash/              # Layar pembuka
│   │   ├── tracking/            # Pelacakan bus (data/domain/presentation)
│   │   ├── trip/                # Perencana perjalanan & pencarian tempat
│   │   └── settings/            # Layar pengaturan
│   ├── l10n/                    # ARB (id/en) + kelas ter-generate
│   └── main.dart                # Titik masuk + tema Material 3
├── l10n.yaml                    # Konfigurasi generasi lokalisasi
├── pubspec.yaml                 # Dependensi & konfigurasi aset
└── API_TransPadang.md           # Dokumentasi teknis API (hasil reverse-engineering)
```

### Cara Menjalankan

**Prasyarat:** Flutter 3.x, Dart `>=3.3.4`, Android SDK (compileSdk 36), perangkat/emulator Android.

```bash
# 1. Ambil dependensi
flutter pub get

# 2. Jalankan (lokalisasi ter-generate otomatis karena generate: true)
flutter run

# 3. Build APK release
flutter build apk --release

# 4. (Opsional, sekali) regenerasi ikon & splash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Regenerasi kelas terjemahan secara manual bila perlu:

```bash
flutter gen-l10n
```

### Catatan Teknis

- **Koreksi sumbu:** `latitude`/`longitude` dari server **terbalik** dan dinormalkan di
  `Bus.fromJson`.
- **Zona waktu:** `last_update` adalah WIB; dikonversi ke UTC (`-7 jam`).
- **Data basi:** bus dengan `last_update` lebih tua dari **5 menit** disembunyikan
  (kecuali data tanpa timestamp).
- **Jam operasional:** `06.00–19.00 WIB` (`AppConfig.operationalStartHour` /
  `operationalEndHour`).
- **ETA:** memakai kecepatan bus bila ≥ 5 km/j, selain itu kecepatan default 20 km/j.
- **Keselamatan legal:** proyek ini tidak berafiliasi dengan Pemerintah Kota Padang.
  Data diambil dari endpoint publik. Dokumen skema API bersifat tidak resmi dan dapat
  berubah tanpa pemberitahuan.

### Lisensi

Dirilis di bawah lisensi **MIT**. Lihat berkas `LICENSE` bila tersedia, atau tambahkan
sebelum publikasi. Nama "TransPadang" dan data terkait adalah milik pemerintah Kota Padang.

---

## English

### Table of Contents

- [About the App](#about-the-app)
- [Features](#features)
- [APIs Used](#apis-used)
- [Architecture & Tech Stack](#architecture--tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Technical Notes](#technical-notes)
- [License](#license)

### About the App

**TPLive** is an Android app to monitor TransPadang buses **live**. It lists the
busiest buses nearest to the user with distance, estimated time of arrival (ETA),
destination, speed, and heading. Users can filter by corridor (K1–K6), inspect the
stop timeline of a bus, and **follow** a bus — the app notifies them when the bus is
about to reach their boarding and alighting stops.

Beyond tracking, users get a **trip planner** that computes TransPadang routes from an
origin to a destination, including **direct** and **one-transfer** options (corridor
changes), with estimated travel and walking times.

> **Disclaimer:** TPLive is **not an official TransPadang app** and has **no
> affiliation** with TransPadang or the Padang City Government. It was built purely to
> make it easier for TransPadang riders to track buses and plan their trips.

### Features

- **Real-time bus list** — nearest buses sorted by distance with distance, ETA,
  destination, and data freshness.
- **Corridor filter** — "All" tab plus K1–K6 chips, each with its own corridor color.
- **Bus detail & stop timeline** — bottom sheet showing the bus position along its
  stop sequence, current & next stop, speed dial, distance, ETA, and trip progress bar.
- **Follow a bus** — an Android foreground service shows an ongoing notification with
  the next stop, distance, ETA, and progress. On Android 16+ it renders as a *live
  update* (`Notification.ProgressStyle`).
- **Arrival alerts** — notifications when the bus is 1–2 stops from the boarding/alighting
  stop, and when it arrives there.
- **Trip planner** — direct routes plus at most one transfer, supporting same-name stop
  transfers and short walking transfers between nearby stops.
- **Destination search** — pick a destination via a TransPadang **stop** or search for a
  **place** (POI) using Nominatim/OSM.
- **Floating pinned bus card** — an "update island" card visible on every page; it
  collapses while scrolling and expands when tapped.
- **Material You (dynamic color)** — theme follows the device wallpaper (Android 12+),
  with light/dark/system modes.
- **Bilingual** — Indonesian and English, optionally following the system language.
- **Operating hours** — a dedicated "service unavailable" state outside 06.00–19.00 WIB.

### APIs Used

The app uses **two API paths**, plus a third-party geocoding service.

#### 1. Realtime WebSocket — Bus Positions

| Item | Value |
|---|---|
| Endpoint | `wss://wstrans.padang.go.id/ws` |
| Authentication | None |
| Data | Position, speed, heading, and route of all buses |
| Interval | Full snapshot re-sent every ~1–2 seconds |

**Flow:**

1. The client opens a WebSocket connection. The server greets:
   ```json
   {"type": "info", "message": "Connected to Trans-Api WebSocket"}
   ```
2. The client subscribes to all buses:
   ```json
   {"type": "subscribeAll"}
   ```
3. The server streams repeated snapshots:
   ```json
   {
     "type": "allBusLocation",
     "data": [
       {
         "bus": "65",
         "longitude": "-0.8982466666666666",
         "latitude": "100.38608888888889",
         "corridor": "K3",
         "last_update": "2026-10-12 14:32:20",
         "direct": "109",
         "route": "RTH Imam Bonjol Ruas Hasanuddin - Pusat Pemerintahan Balai Kota Padang",
         "speed": "32"
       }
     ]
   }
   ```

**Per-bus field schema:**

| Field | Type | Description |
|---|---|---|
| `bus` | string | Bus number/ID (e.g. `"65"`) |
| `longitude` | string | **Actually LATITUDE** (server swaps the fields) |
| `latitude` | string | **Actually LONGITUDE** (server swaps the fields) |
| `corridor` | string | Corridor code: `K1`…`K6` |
| `route` | string | Corridor route name |
| `direct` | string | Heading (degrees, 0–360) |
| `speed` | string | Speed (km/h) |
| `last_update` | string | **WIB (UTC+7)** timestamp, format `yyyy-MM-dd HH:mm:ss` |

**Important notes:**

- The `latitude` and `longitude` fields are **swapped**. Normalize as
  `lat = json["longitude"]`, `lng = json["latitude"]` (see
  `lib/features/tracking/data/bus_model.dart`).
- `last_update` is in **WIB**, converted to UTC by subtracting 7 hours.
- Operating hours: **06.00–19.00 WIB**. No bus data outside those hours.
- The native service also uses a per-corridor subscription:
  `{"type":"subscribeKoridor","koridor":"K3"}`, which replies with `busLocationByKoridor`.

#### 2. REST — api-superapp (TransPadang)

Base URL: `https://api-superapp.padang.go.id/trans-padang/`

| Method | Path | Description |
|---|---|---|
| `GET` | `/trans-padang/` | Base / index |
| `GET` | `/trans-padang/api/booklet` | Corridor booklet (route & schedule info) |
| `GET` | `/trans-padang/api/dinas/?perPage=2000` | Agencies/operators list |
| `GET` | `/trans-padang/api/kontak` | Contact / WhatsApp |

> **Note:** these REST endpoints are used by the official "Padang Mobile" app and
> respond with **HTTP 429 Too Many Requests** for direct public access (likely requiring
> a token / per-IP rate limit). TPLive does **not** depend on REST: the stop dataset is
> bundled locally (`assets/halte.json`), while bus positions come purely from the
> WebSocket.

#### 3. Geocoding — Nominatim (OpenStreetMap)

| Item | Value |
|---|---|
| Host | `nominatim.openstreetmap.org` |
| Purpose | Place (POI) search when choosing a destination |
| Bounds | Viewbox around Padang, `bounded=1`, `countrycodes=id` |
| Language | `id` |

Per Nominatim's usage policy, the app sends a clear User-Agent and avoids excessive calls.

### Architecture & Tech Stack

**Stack:**

- **Flutter** (Dart SDK `>=3.3.4 <4.0.0`), Material 3.
- **flutter_riverpod** — state management.
- **web_socket_channel** — realtime WebSocket connection.
- **geolocator** — device GPS location.
- **latlong2** — geo math (Haversine, bearing, segment projection).
- **shared_preferences** — persistent theme/language preferences.
- **intl** + **flutter_localizations** — localization (ARB → generated classes).
- **dynamic_color** — Material You (wallpaper-based color, Android 12+).
- **okhttp3** (Android native) — WebSocket inside the foreground service.

**Architecture pattern** per feature: `data` → `domain` → `presentation`.

- `TransWsDataSource` manages a single connection, **auto-reconnect** with
  *exponential backoff + jitter*, the `subscribeAll` subscription, and pausing while the
  app is in the background.
- `HalteTracker` maps a bus position onto its corridor's stop sequence, resolves the
  direction (`pergi`/`pulang`), current & next stops, and origin/destination terminuses.
- `HeadingTracker` estimates the real movement heading from position history (a
  distance-weighted vector sum), because the server's `direct` field can be noisy.
- `TripPlanner` computes direct routes plus at most one transfer, with time penalties and
  walking distances.
- `FollowAlertEngine` decides when "approaching" / "time to board/alight" alerts fire
  (pure, I/O-free).

**Android native layer** (`android/app/src/main/kotlin/.../`):

- `FollowService.kt` — a foreground service (`dataSync`) that opens its own WebSocket
  (OkHttp), subscribes to a single corridor, and updates an ongoing notification. It
  stops automatically when bus data goes stale for > 5 minutes.
- `MainActivity.kt` — `MethodChannel` `id.dwiky.transpadang_live/follow`
  (`startFollow`, `stopFollow`, `isFollowing`, `getFollowed`,
  `requestNotificationPermission`, `showEventNotification`).
- `HalteMath.kt` — native-side stop progress & ETA computation.

### Project Structure

```
transpadang_live/
├── android/                     # Android project (Kotlin native service)
│   └── app/src/main/kotlin/id/dwiky/transpadang_live/
│       ├── MainActivity.kt      # MethodChannel + event notifications
│       ├── FollowService.kt     # "Follow bus" foreground service
│       └── HalteMath.kt         # Native stop/ETA math
├── assets/
│   ├── halte.json               # Stop dataset per corridor (2 directions)
│   └── logo/                    # Icons & splash
├── lib/
│   ├── core/
│   │   ├── app_navigator.dart   # Global navigator key + observer
│   │   ├── config.dart          # Central config (URLs, operating hours)
│   │   ├── follow_service.dart  # MethodChannel wrapper (follow)
│   │   └── settings.dart        # Theme/language prefs (SharedPreferences)
│   ├── features/
│   │   ├── splash/              # Splash screen
│   │   ├── tracking/            # Bus tracking (data/domain/presentation)
│   │   ├── trip/                # Trip planner & place search
│   │   └── settings/            # Settings screen
│   ├── l10n/                    # ARB (id/en) + generated classes
│   └── main.dart                # Entry point + Material 3 theme
├── l10n.yaml                    # Localization generation config
├── pubspec.yaml                 # Dependencies & asset config
└── API_TransPadang.md           # API technical docs (reverse-engineered)
```

### Getting Started

**Prerequisites:** Flutter 3.x, Dart `>=3.3.4`, Android SDK (compileSdk 36), an Android device/emulator.

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run (localizations auto-generate because generate: true)
flutter run

# 3. Build a release APK
flutter build apk --release

# 4. (Optional, one-off) regenerate icons & splash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Manually regenerate translation classes if needed:

```bash
flutter gen-l10n
```

### Technical Notes

- **Axis correction:** the server's `latitude`/`longitude` are **swapped** and normalized
  in `Bus.fromJson`.
- **Time zone:** `last_update` is WIB; converted to UTC (`-7 hours`).
- **Stale data:** buses whose `last_update` is older than **5 minutes** are hidden
  (unless the datum has no timestamp).
- **Operating hours:** `06.00–19.00 WIB` (`AppConfig.operationalStartHour` /
  `operationalEndHour`).
- **ETA:** uses the bus speed when ≥ 5 km/h, otherwise a default of 20 km/h.
- **Legal note:** this project is not affiliated with the Padang City Government. Data is
  taken from public endpoints. The API schema documentation is unofficial and may change
  without notice.

### License

Released under the **MIT** license. See the `LICENSE` file if present, or add one before
publishing. The name "TransPadang" and its data belong to the Padang City Government.

---

<p align="center">Made for Padang public transport riders.</p>
