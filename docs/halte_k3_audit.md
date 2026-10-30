# Audit Halte K3

Laporan ini menggantikan audit lama. Daftar halte K3 sekarang berasal dari
**survey manual** (nama + koordinat dari lapangan/Google Maps), bukan hasil
interpolasi antar-halte lama. Nilai lama tidak dipakai lagi.

## Sumber data

| Berkas | Isi |
| --- | --- |
| `scripts/data/manual/K3_pulang.txt` | Taman Digital → RTH Imam Bonjol, 46 halte |
| `scripts/data/manual/K3_pergi.txt` | RTH Imam Bonjol → Taman Digital, 50 halte |
| `scripts/import_halte_txt.py` | importer + validasi (dry-run default, `--write` menerapkan) |
| `assets/halte.json` | hasil: blok `K3`, id `k3-pulang-01…46` / `k3-pergi-01…50` |

Kedua berkas txt adalah sumber kebenaran. `id` digenerate ulang saat impor.

## Validasi

Jalur acuan: `assets/routes/K3.geojson` (geometri yang benar-benar digambar
aplikasi). `assets/corridor_routes.json` untuk K3 sudah disalin dari geojson
agar alat lain (audit, map preview) melihat jalur yang sama.

| Metrik | `pulang` | `pergi` |
| --- | --- | --- |
| Jumlah halte | 46 | 50 |
| Total jarak antar-halte | 16,59 km | 18,87 km |
| Panjang jalur | 17,47 km | 21,30 km |
| Rasio jarak/jalur | 0,95 | 0,89 |
| Gap terpendek | 148 m | 54 m |
| Gap < 25 m (blok menumpuk) | 0 | 0 |
| Offset > 60 m dari jalur | 4 | 2 |

Offset > 60 m berasal dari shelter yang memang berada di sisi jalan, bukan
kesalahan koordinat:

- `pulang`: Kantor Damkar Padang 76 m, Plaza Andalas 114 m, TK Adhyaksa XXVI
  145 m, Pondok 124 m
- `pergi`: Monumen Merpati Muaro Lasak 73 m, Pegadaian 78 m

Tidak ada nama ganda dalam satu arah, dan `dart run scripts/audit_halte.dart`
melaporkan **0 temuan** untuk K3.

## Perubahan dari data lama

| Arah | Halte lama | Halte baru | Nama yang sama | Nama hilang | Nama baru |
| --- | --- | --- | --- | --- | --- |
| `pergi` | 45 | 50 | 7 | 37 | 43 |
| `pulang` | 49 | 46 | 7 | 42 | 39 |

Perpindahan terbesar untuk halte yang namanya dipertahankan:

- `pulang`: Masjid Raya Sumbar 1.235 m, Masjid Al Wustha Purus 924 m,
  Simpang Balai Baru 266 m, Plaza Andalas 209 m
- `pergi`: Jembatan Baru Siteba 511 m, Simpang Berok 369 m, Pasar Raya 348 m

Halte yang dihapus dari K3 `pulang` berdasarkan koreksi survey: BPKAD Prov.
Sumbar (milik arah pergi), Seberang Poltekkes Siteba Padang (arah pergi),
Museum Adityawarman (tidak ada haltenya di ruas ini).

Dua arah dipakai bersama oleh 3 nama yang menyatu di peta (nama sama, jarak
≤ 30 m): Masjid An Nur Lolong Karan, Simpang Pagang Dalam Siteba, RTH Imam
Bonjol Ruas Hasanuddin. Total 96 entri → 93 marker unik.

## Cara memperbarui

```powershell
# 1. edit scripts/data/manual/K3_pulang.txt / K3_pergi.txt (Notepad, UTF-8)
# 2. dry-run: lihat tabel jarak + offset
python scripts/import_halte_txt.py --corridor K3 --dir pulang --file scripts/data/manual/K3_pulang.txt
python scripts/import_halte_txt.py --corridor K3 --dir pergi  --file scripts/data/manual/K3_pergi.txt

# 3. terapkan
python scripts/import_halte_txt.py --corridor K3 --dir pulang --file scripts/data/manual/K3_pulang.txt --write
python scripts/import_halte_txt.py --corridor K3 --dir pergi  --file scripts/data/manual/K3_pergi.txt  --write

# 4. verifikasi
dart run scripts/audit_halte.dart
flutter test test/trip_planner_test.dart
```

`python scripts/fix_halte_coords.py --corridor K3` sekarang berhenti dengan
kode 2 karena K3 masuk `MANUAL_CORRIDORS`; skrip itu tidak boleh menimpa
koordinat survey dengan nilai interpolasi/OSM. Gunakan `--force` hanya bila
memang ingin menjalankan heuristik lama.
