# Audit koordinat halte K3

## Temuan

- **19 halte** menempati koordinat yang sama dengan tetangganya, sehingga membentuk 4 blok tumpang tindih:
  - `pergi` #0–#8 (9 halte): Ruas Hasanuddin, Pasar Raya, Simp. Dobi, Museum Adityawarman, Mr. DIY, Plan B, Masjid Al Hakim, Gedung Joang 45, Taman Budaya
  - `pergi` #43–#44 (2 halte): RS Siti Rahmah, Taman Digital / Balai Kota
  - `pulang` #0–#1 (2 halte): Taman Digital / Balai Kota, RS Siti Rahmah
  - `pulang` #43–#48 (6 halte): Masjid Al Hakim, Plan B, Mr. DIY, Museum Adityawarman, Simp. Dobi, Ruas Hasanuddin
  Akibatnya `HalteTracker` tidak punya segmen untuk dihitung: jarak antartetangga 0 m dan peta menggambar satu penanda untuk banyak halte.

Sumber acuan, berurut menurut tingkat kepercayaan:

1. `scripts/data/halte_overrides.json` — koordinat yang sudah dicek manual.
2. Node `highway=bus_stop` OpenStreetMap (snapshot `scripts/data/osm_halte_padang.json`, data (c) kontributor OSM, lisensi ODbL).
3. Nama halte yang sama di koridor lain (K1/K2/K5) yang tidak menumpuk.
4. Penyebaran merata di sepanjang jalur koridor (`interpolated`).

- Halte diperiksa: **94**
- Koordinat diubah (>= 3 m): **16**
- Perlu cek lapangan: **3**

## Catatan struktural

- Jejak GPS arah `pergi` baru dimulai di Jl. Samudra (-0.950221, 100.352161), sekitar 1,2 km setelah terminus sebenarnya di Jl. Hasanuddin. Sembilan halte pertama karena itu berada di luar garis jalur yang digambar peta — posisinya benar, tapi polyline `corridor_routes.json` arah pergi belum mencakup blok itu. Perlu rekam ulang jejak arah pergi untuk segmen tersebut.
- Urutan halte di blok pusat kota (Pasar Raya → Simp. Dobi → Museum Adityawarman → Mr. DIY → Plan B → Masjid Al Hakim → Gedung Joang 45) belum mengikuti jalan: Museum Adityawarman berada ~500 m di utara Mr. DIY, jadi rute urutannya belum monoton. Koordinat sudah benar, urutannya yang masih perlu diputuskan.

## Perlu cek lapangan

| Arah | Halte | Lat | Lng | Catatan |
|------|-------|-----|-----|---------|
| pergi | Masjid Al Hakim | -0.955100 | 100.362800 | interpolasi antara Plan B dan Gedung Joang 45 | PERLU CEK LAPANGAN |
| pergi | Taman Budaya | -0.954530 | 100.355090 | OSM 'Taman Budaya Padang' (leisure/gallery) | PERLU CEK LAPANGAN |
| pulang | Masjid Al Hakim | -0.955100 | 100.362800 | interpolasi antara Plan B dan Gedung Joang 45 | PERLU CEK LAPANGAN |

## Arah `pergi` — jalur 16.01 km

| # | Halte | Lat lama | Lng lama | Lat baru | Lng baru | Geser | Sumber |
|---|-------|----------|----------|----------|----------|-------|--------|
| 0 | Ruas Hasanuddin | -0.950226 | 100.352127 | -0.955389 | 100.362579 | 1296 m | override — ujung loop pulang (Jl. Hasanuddin) |
| 1 | Pasar Raya | -0.950226 | 100.352127 | -0.953480 | 100.364060 | 1375 m | override — koridor K2 (pergi 'Pasar Raya') |
| 2 | Simp. Dobi | -0.950226 | 100.352127 | -0.953269 | 100.363201 | 1277 m | override — koridor K2 (pulang 'Simp. Dobi') |
| 3 | Museum Adityawarman | -0.950226 | 100.352127 | -0.950677 | 100.363656 | 1283 m | override — koridor K5 (pulang 'Museum Adityawarman') |
| 4 | Mr. DIY | -0.950226 | 100.352127 | -0.954953 | 100.362266 | 1244 m | override — koridor K2 (pulang 'Mr. DIY') |
| 5 | Plan B | -0.950226 | 100.352127 | -0.955514 | 100.361954 | 1241 m | override — koridor K2 (pulang 'Plan B') |
| 6 | Masjid Al Hakim | -0.950226 | 100.352127 | -0.955100 | 100.362800 | 1305 m | override — interpolasi antara Plan B dan Gedung Joang 45 | PERLU CEK LAPANGAN |
| 7 | Gedung Joang 45 | -0.950226 | 100.352127 | -0.954745 | 100.363629 | 1374 m | override — K3 pulang (satu-satunya nilai yang tidak menumpuk) |
| 8 | Taman Budaya | -0.950226 | 100.352127 | -0.954530 | 100.355090 | 581 m | override — OSM 'Taman Budaya Padang' (leisure/gallery) | PERLU CEK LAPANGAN |
| 43 | RS Siti Rahmah | -0.871082 | 100.382369 | -0.871968 | 100.382951 | 118 m | osm:14300281726 — node OSM 'Halte RSI Siti Rahma II' |

## Arah `pulang` — jalur 20.88 km

| # | Halte | Lat lama | Lng lama | Lat baru | Lng baru | Geser | Sumber |
|---|-------|----------|----------|----------|----------|-------|--------|
| 1 | RS Siti Rahmah | -0.871082 | 100.382369 | -0.872061 | 100.383342 | 153 m | override — OSM node 14300281727 'Halte RSI Siti Rahma I' |
| 43 | Masjid Al Hakim | -0.955383 | 100.362576 | -0.955100 | 100.362800 | 40 m | override — interpolasi antara Plan B dan Gedung Joang 45 | PERLU CEK LAPANGAN |
| 44 | Plan B | -0.955383 | 100.362576 | -0.955514 | 100.361954 | 71 m | override — koridor K2 (pulang 'Plan B') |
| 45 | Mr. DIY | -0.955383 | 100.362576 | -0.954953 | 100.362266 | 59 m | override — koridor K2 (pulang 'Mr. DIY') |
| 46 | Museum Adityawarman | -0.955383 | 100.362576 | -0.950677 | 100.363656 | 537 m | override — koridor K5 (pulang 'Museum Adityawarman') |
| 47 | Simp. Dobi | -0.955383 | 100.362576 | -0.953269 | 100.363201 | 245 m | override — koridor K2 (pulang 'Simp. Dobi') |
