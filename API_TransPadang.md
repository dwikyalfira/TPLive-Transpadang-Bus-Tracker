# API TransPadang — Daftar Penggunaan & Contoh

Dokumen ini adalah hasil rekonstruksi dari:
- source code `transpadang_live` (klien WebSocket),
- analisis APK resmi "Padang Mobile" (`padang_base.apk` / `padang_arm64.apk`),
- uji koneksi langsung ke server (WebSocket) pada 2026-10-12.

Ada **2 jalur API**:

| Jalur | Host | Data | Auth |
|---|---|---|---|
| WebSocket (realtime) | `wss://wstrans.padang.go.id/ws` | posisi/kecepatan/arah/rute semua bus | Tidak perlu |
| REST | `https://api-superapp.padang.go.id/trans-padang/` | booklet, dinas, kontak (dan data halte/rute) | Dibatasi (HTTP 429 untuk akses publik langsung) |

---

## 1. WebSocket — Realtime Lokasi Bus

### 1.1 Koneksi & handshake

```
GET /ws  (upgrade WebSocket)
Host: wstrans.padang.go.id
```

Segera setelah koneksi terbuka, server mengirim pesan sapaan:

```json
{"type": "info", "message": "Connected to Trans-Api WebSocket"}
```

### 1.2 Subskripsi semua bus

Kirim (text frame):

```json
{"type": "subscribeAll"}
```

Server membalas:

```json
{"type": "subscriptionConfirm", "subscription": "all", "message": "Subscribed to all corridors"}
```

### 1.3 Stream data bus — `allBusLocation`

Setelah subskripsi, server **mengirim snapshot penuh semua bus berulang setiap ±1–2 detik**. Satu pesan besar dipecah menjadi beberapa frame WebSocket (frame pertama `Text`, sisanya `Continuation`, terakhir `Continuation` panjang 0).

Contoh payload (hasil tangkapan live):

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
    },
    {
      "bus": "48",
      "longitude": "-0.9294",
      "latitude": "100.42665777777778",
      "corridor": "K6",
      "last_update": "2026-10-12 14:30:08",
      "direct": "58",
      "route": "CGV Pasar Raya Padang - Politeknik Negeri Padang",
      "speed": "9"
    }
  ]
}
```

### 1.4 Skema field per bus

| Field | Tipe | Keterangan |
|---|---|---|
| `bus` | string | Nomor/ID bus (contoh `"65"`) |
| `longitude` | string | **Sebenarnya LATITUDE** (server mengirim terbalik) |
| `latitude` | string | **Sebenarnya LONGITUDE** |
| `corridor` | string | Kode koridor: `K1`…`K6` |
| `route` | string | Nama rute koridor |
| `direct` | string | Arah/heading (derajat, 0–360) |
| `speed` | string | Kecepatan (km/jam) |
| `last_update` | string | Timestamp **WIB (UTC+7)**, format `yyyy-MM-dd HH:mm:ss` |

Catatan penting:
- Field `latitude`/`longitude` **terbalik**. Normalisasi: `lat = json["longitude"]`, `lng = json["latitude"]`.
- `last_update` adalah waktu **WIB**, bukan UTC → perlu dikurangi 7 jam bila diproses sebagai UTC.
- Jam operasional TransPadang: **05.00–20.00 WIB**. Di luar jam itu tidak ada data bus.

### 1.5 Contoh kode Dart (sesuai pola `transpadang_live`)

Menggunakan package `web_socket_channel`:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

const wsUrl = 'wss://wstrans.padang.go.id/ws';

class Bus {
  final String number;
  final double lat;   // sudah dinormalisasi dari field 'longitude'
  final double lng;   // sudah dinormalisasi dari field 'latitude'
  final String corridor;
  final String route;
  final double? heading;
  final double? speedKmh;
  final DateTime? lastUpdateUtc;
  const Bus({required this.number, required this.lat, required this.lng,
    required this.corridor, required this.route,
    this.heading, this.speedKmh, this.lastUpdateUtc});

  factory Bus.fromJson(Map<String, dynamic> j) {
    double? d(v) => v == null ? null : double.tryParse('$v');
    DateTime? parseUtc(v) {
      final p = DateTime.tryParse('$v'.replaceFirst(' ', 'T'));
      return p == null ? null : p.toUtc().subtract(const Duration(hours: 7));
    }
    return Bus(
      number: '${j['bus'] ?? ''}',
      lat: d(j['longitude']) ?? 0,          // TERBALIK dari server
      lng: d(j['latitude']) ?? 0,            // TERBALIK dari server
      corridor: '${j['corridor'] ?? ''}',
      route: '${j['route'] ?? ''}',
      heading: d(j['direct']),
      speedKmh: d(j['speed']),
      lastUpdateUtc: parseUtc(j['last_update']),
    );
  }
}

void main() {
  final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

  channel.stream.listen((raw) {
    if (raw is! String) return;
    final msg = jsonDecode(raw);
    if (msg is! Map) return;

    switch (msg['type']) {
      case 'info':
        print('Terhubung: ${msg['message']}');
        channel.sink.add('{"type":"subscribeAll"}');
      case 'subscriptionConfirm':
        print('Subskripsi OK: ${msg['message']}');
      case 'allBusLocation':
        final buses = (msg['data'] as List)
            .whereType<Map>()
            .map((e) => Bus.fromJson(e.cast<String, dynamic>()))
            .toList();
        print('Buses aktif: ${buses.length}');
        for (final b in buses.take(3)) {
          print('Bus ${b.number} | ${b.corridor} | ${b.route} | ${b.lat},${b.lng}');
        }
    }
  });
}
```

Contoh klien terminal (menggunakan `wscat`):

```bash
# install: npm i -g wscat
wscat -c wss://wstrans.padang.go.id/ws
# lalu ketik:
{"type":"subscribeAll"}
```

---

## 2. REST — api-superapp (TransPadang)

Ditemukan pada APK resmi. Semua di bawah base:

```
https://api-superapp.padang.go.id/trans-padang/
```

| Method | Path | Deskripsi | Contoh |
|---|---|---|---|
| `GET` | `/trans-padang/` | Base / index | `GET https://api-superapp.padang.go.id/trans-padang/` |
| `GET` | `/trans-padang/api/booklet` | Booklet koridor (info rute & jadwal) | `GET https://api-superapp.padang.go.id/trans-padang/api/booklet` |
| `GET` | `/trans-padang/api/dinas/?perPage=2000` | Daftar dinas/operator | `GET https://api-superapp.padang.go.id/trans-padang/api/dinas/?perPage=2000` |
| `GET` | `/trans-padang/api/kontak` | Kontak / WhatsApp | `GET https://api-superapp.padang.go.id/trans-padang/api/kontak` |

Catatan:
- Saat pengujian publik langsung, semua endpoint ini membalas **HTTP 429 Too Many Requests**. Kemungkinan server/WAF mewajibkan token masuk (login app "Padang Mobile") atau mengatur rate-limit per IP, sehingga perlu intervensi traffic (mitmproxy) untuk mengetahui header/token yang sah.
- Data **halte & rute** (mis. nama halte "Toyota Auto 200", koordinat halte, koridor yang melayani) diambil app resmi dari backend ini via provider `getBusStopAndRoutes` lalu **di-cache di SharedPreferences** dengan kunci `trans_v3_bus_stop` dan `trans_v3_bus_stop_timestamp`. Endpoint WS **tidak** menyediakannya.
- Fitur "menuju ke Halte X" di app resmi dihitung di sisi klien: daftar halte master (REST) + posisi/heading bus (`direct`) dari WS.

### Contoh `curl`

```bash
curl -i 'https://api-superapp.padang.go.id/trans-padang/api/booklet' \
  -H 'User-Agent: okhttp/4.9.0' \
  -H 'Accept: application/json'
```

---

## 3. Ringkasan alur memakai API (untuk meniru fitur app resmi)

1. Buka WS → `subscribeAll` → terima `allBusLocation` tiap ±1–2 dtk.
2. Normalisasi field `latitude`/`longitude` (server terbalik) & konversi `last_update` WIB→UTC.
3. Posisi bus + `direct` dipakai untuk memfilter/urutan bus terdekat dan menentukan "menuju halte berikutnya".
4. Nama & koordinat halte diambil dari data master (REST TransPadang) — belum tersedia publik; untuk sementara bisa skrap peta jaringan resmi Dishub/PDF sebagai fallback.

---

*Dokumen disusun dari reverse-engineering; skema API REST tidak resmi dan dapat berubah tanpa pemberitahuan.*