#!/usr/bin/env python3
"""Impor daftar halte manual (teks) ke `assets/halte.json`.

Kenapa ada skrip ini
--------------------
Daftar halte kadang disusun manual di Notepad: nama + koordinat dari Google
Maps. Mengetik JSON langsung rawan salah kurung, dan koordinat yang menumpuk
tidak terlihat sampai aplikasi dijalankan. Skrip ini membaca teks itu,
memvalidasinya terhadap geometri jalur koridor, lalu menulis ulang satu arah
koridor di `assets/halte.json`.

Format yang diterima
--------------------
Satu baris per halte, urut sesuai arah perjalanan bus:

    Nama halte - -0.955389, 100.362579
    Nama halte | -0.955389 | 100.362579
    Nama halte<TAB>-0.955389<TAB>100.362579

atau blok tiga baris (format salin-tempel Google Maps):

    Nama halte
    -0.955389, 100.362579
    -K3, K4                  <- opsional, diabaikan (anotasi koridor)

Baris kosong dan baris berawalan `#` diabaikan. Desimal koma (`-0,9554`) juga
diterima. Baris `# label: ...` mengisi label arah bila ada.

Contoh
------
    python scripts/import_halte_txt.py --corridor K3 --dir pulang \
        --file scripts/data/manual/K3_pulang.txt            # dry-run
    python scripts/import_halte_txt.py --corridor K3 --dir pulang \
        --file scripts/data/manual/K3_pulang.txt --write    # tulis

Kode keluar 1 bila ada error (koordinat di luar Padang, dua halte < 25 m,
nama duplikat, dsb) sehingga aman dipakai di alur build.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HALTE_PATH = ROOT / "assets" / "halte.json"
ROUTES_PATH = ROOT / "assets" / "corridor_routes.json"
GEOJSON_DIR = ROOT / "assets" / "routes"

EARTH_R = 6371008.8

# Kotak kasar Kota Padang; koordinat di luarnya hampir pasti salah.
PADANG_BBOX = (-1.10, -0.75, 100.25, 100.55)

MIN_GAP_M = 25.0  # dua halte berurutan harus terpisah minimal ini
MAX_OFFSET_M = 60.0  # jarak halte ke jalur koridor
BACKWARD_M = 50.0  # toleransi urutan mundur (loop sahkan sebagian kasus)
RATIO_TOLERANCE = 0.30  # panjang rute vs jumlah jarak antar-halte

COORD_RE = re.compile(r"^(-?\d+(?:[.,]\d+)?)\s*,\s*(-?\d+(?:[.,]\d+)?)$")
TAG_RE = re.compile(r"^-\s*[Kk][1-6](?:\s*[,\s]\s*[Kk][1-6])*\s*$")
# Dua angka terakhir pada baris (untuk format satu baris).
NUMS_RE = re.compile(r"(-?\d+(?:[.,]\d+)?)\s*,\s*(-?\d+(?:[.,]\d+)?)\s*$")


@dataclass
class Stop:
    nama: str
    lat: float
    lng: float


@dataclass
class Row:
    index: int
    stop: Stop
    gap: float
    arc: float
    offset: float
    errors: list[str]
    warnings: list[str]


def load_json(path: Path):
    return json.loads(path.read_bytes().decode("utf-8-sig"))


def haversine(a: tuple[float, float], b: tuple[float, float]) -> float:
    lat1, lon1 = math.radians(a[0]), math.radians(a[1])
    lat2, lon2 = math.radians(b[0]), math.radians(b[1])
    h = (
        math.sin((lat2 - lat1) / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    )
    return 2 * EARTH_R * math.asin(math.sqrt(h))


class Polyline:
    def __init__(self, points: list[list[float] | tuple[float, float]]) -> None:
        self.pts = [(float(p[0]), float(p[1])) for p in points]
        self.cum = [0.0]
        for i in range(1, len(self.pts)):
            self.cum.append(self.cum[-1] + haversine(self.pts[i - 1], self.pts[i]))

    @property
    def length(self) -> float:
        return self.cum[-1]

    def project(self, p: tuple[float, float]) -> tuple[float, float]:
        """(arc_length_m, perpendicular_offset_m) ke vertex terdekat."""
        best = (0.0, float("inf"))
        for i in range(len(self.pts) - 1):
            a, b = self.pts[i], self.pts[i + 1]
            seg = self.cum[i + 1] - self.cum[i]
            if seg <= 0:
                continue
            k = math.cos(math.radians(a[0]))
            ax, ay = a[1] * k, a[0]
            bx, by = b[1] * k, b[0]
            px, py = p[1] * k, p[0]
            dx, dy = bx - ax, by - ay
            t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
            q = (a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]))
            d = haversine(p, q)
            if d < best[1]:
                best = (self.cum[i] + t * seg, d)
        return best


def load_route(corridor: str, direction: str) -> tuple[Polyline | None, str]:
    """Jalur koridor: `assets/routes/<K>.geojson` dulu (menang di aplikasi)."""
    geo = GEOJSON_DIR / f"{corridor}.geojson"
    if geo.exists():
        data = load_json(geo)
        for feature in data.get("features", []):
            props = feature.get("properties") or {}
            if props.get("direction", "").lower() != direction:
                continue
            geom = feature.get("geometry") or {}
            if geom.get("type") != "LineString":
                continue
            # GeoJSON = [lng, lat]
            pts = [(c[1], c[0]) for c in geom["coordinates"]]
            if len(pts) >= 2:
                return Polyline(pts), geo.name
    if ROUTES_PATH.exists():
        data = load_json(ROUTES_PATH)
        pts = data.get(corridor, {}).get(direction)
        if pts:
            return Polyline(pts), ROUTES_PATH.name
    return None, "-"


def parse_file(path: Path) -> tuple[list[Stop], str | None, list[str]]:
    """Kembalikan (stops, label, errors)."""
    stops: list[Stop] = []
    label: str | None = None
    errors: list[str] = []
    pending_name: str | None = None

    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#"):
            meta = line.lstrip("#").strip()
            if meta.lower().startswith("label:"):
                label = meta.split(":", 1)[1].strip()
            continue
        if len(line) > 5 and set(line) == {"-"}:
            errors.append(f"baris {lineno}: pemisah '---' tidak boleh ada dalam satu file arah")
            continue
        if TAG_RE.match(line):
            # Anotasi koridor ("-K3, K4"); tidak disimpan, koridor diturunkan
            # aplikasi dari daftar halte tiap koridor.
            continue

        coords = COORD_RE.match(line)
        if coords:
            if pending_name is None:
                errors.append(f"baris {lineno}: koordinat tanpa nama halte di atasnya")
                continue
            stops.append(
                Stop(
                    pending_name,
                    float(coords.group(1).replace(",", ".")),
                    float(coords.group(2).replace(",", ".")),
                )
            )
            pending_name = None
            continue

        single = NUMS_RE.search(line)
        if single and not pending_name:
            name = line[: single.start()].strip(" -|\t")
            if not name:
                errors.append(f"baris {lineno}: nama halte kosong")
                continue
            stops.append(
                Stop(
                    name,
                    float(single.group(1).replace(",", ".")),
                    float(single.group(2).replace(",", ".")),
                )
            )
            continue

        if pending_name is not None:
            errors.append(f"baris {lineno}: '{pending_name}' tidak punya koordinat")
        pending_name = line

    if pending_name is not None:
        errors.append(f"'{pending_name}' tidak punya koordinat di akhir file")
    return stops, label, errors


def validate(stops: list[Stop], route: Polyline | None) -> tuple[list[Row], list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    rows: list[Row] = []
    seen: dict[str, int] = {}
    prev_arc = -1.0
    total_gap = 0.0

    if len(stops) < 2:
        errors.append(f"butuh minimal 2 halte, hanya ada {len(stops)}")

    for i, stop in enumerate(stops, 1):
        p = (stop.lat, stop.lng)
        row_errors: list[str] = []
        row_warnings: list[str] = []

        if not (PADANG_BBOX[0] <= stop.lat <= PADANG_BBOX[1]):
            row_errors.append("lat di luar bbox Padang")
        if not (PADANG_BBOX[2] <= stop.lng <= PADANG_BBOX[3]):
            row_errors.append("lng di luar bbox Padang")

        key = re.sub(r"\s+", " ", stop.nama.strip().lower())
        if key in seen:
            row_errors.append(f"nama duplikat (sudah ada di #{seen[key]})")
        else:
            seen[key] = i

        gap = 0.0 if i == 1 else haversine((stops[i - 2].lat, stops[i - 2].lng), p)
        total_gap += gap
        if 0 < gap < MIN_GAP_M:
            row_errors.append(f"jarak {gap:.0f} m < {MIN_GAP_M:.0f} m dari halte sebelumnya")

        arc = offset = 0.0
        if route is not None:
            arc, offset = route.project(p)
            if offset > MAX_OFFSET_M:
                row_warnings.append(f"offset {offset:.0f} m dari jalur")
            if arc < prev_arc - BACKWARD_M:
                row_warnings.append(f"urutan mundur {prev_arc - arc:.0f} m (loop?)")
            prev_arc = max(prev_arc, arc)

        rows.append(Row(i, stop, gap, arc, offset, row_errors, row_warnings))
        errors.extend(f"#{i} {stop.nama}: {e}" for e in row_errors)
        warnings.extend(f"#{i} {stop.nama}: {w}" for w in row_warnings)

    if route is not None and route.length > 0 and len(stops) >= 2:
        ratio = total_gap / route.length
        if abs(ratio - 1.0) > RATIO_TOLERANCE:
            warnings.append(
                f"total jarak antar-halte {total_gap / 1000:.2f} km vs jalur "
                f"{route.length / 1000:.2f} km (rasio {ratio:.2f}) — cek urutan/koordinat"
            )
    return rows, errors, warnings


def render(rows: list[Row], route_label: str) -> str:
    out = [
        f"{'#':>3}  {'nama':<38} {'lat':>10} {'lng':>11} {'gap':>6} {'offset':>6}  catatan",
        f"{'-' * 3}  {'-' * 38} {'-' * 10} {'-' * 11} {'-' * 6} {'-' * 6}  {'-' * 7}",
    ]
    for row in rows:
        note = " ".join(["!" + e for e in row.errors] + ["?" + w for w in row.warnings])
        out.append(
            f"{row.index:>3}  {row.stop.nama[:38]:<38} {row.stop.lat:>10.6f} "
            f"{row.stop.lng:>11.6f} {row.gap:>6.0f} {row.offset:>6.0f}  {note}"
        )
    out.append("")
    out.append(f"jalur acuan: {route_label}")
    return "\n".join(out)


def write_direction(corridor: str, direction: str, label: str | None, stops: list[Stop]) -> None:
    data = load_json(HALTE_PATH)
    corridor_data = data.setdefault(corridor, {"arah": {}})
    arah = corridor_data.setdefault("arah", {})
    old = arah.get(direction, {})
    arah[direction] = {
        "label": label or old.get("label", ""),
        "halte": [
            {
                "id": f"{corridor.lower()}-{direction}-{i:02d}",
                "nama": s.nama,
                "lat": round(s.lat, 6),
                "lng": round(s.lng, 6),
            }
            for i, s in enumerate(stops, 1)
        ],
    }
    with open(HALTE_PATH, "w", encoding="utf-8", newline="\r\n") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)
        fh.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--corridor", required=True, help="kode koridor, mis. K3")
    parser.add_argument("--dir", required=True, choices=["pergi", "pulang"])
    parser.add_argument("--file", required=True, type=Path, help="berkas teks daftar halte")
    parser.add_argument("--label", help="label arah (default: dari header '# label:' atau label lama)")
    parser.add_argument("--write", action="store_true", help="tulis ke assets/halte.json")
    args = parser.parse_args()

    corridor = args.corridor.strip().upper()
    stops, label, parse_errors = parse_file(args.file)
    route, route_label = load_route(corridor, args.dir)
    rows, errors, warnings = validate(stops, route)

    print(render(rows, route_label))
    print()
    print(
        f"{corridor}/{args.dir}: {len(stops)} halte, "
        f"{sum(r.gap for r in rows) / 1000:.2f} km antar-halte"
    )
    if label:
        print(f"label: {label}")

    for err in parse_errors + errors:
        print(f"ERROR: {err}", file=sys.stderr)
    for warn in warnings:
        print(f"WARN : {warn}")

    if parse_errors or errors:
        print("\nTidak ada yang ditulis (perbaiki ERROR di atas).", file=sys.stderr)
        return 1

    if not args.write:
        print("\nDry-run. Tambahkan --write untuk menerapkan.")
        return 0

    write_direction(corridor, args.dir, args.label or label, stops)
    print(f"\nDitulis ke {HALTE_PATH.relative_to(ROOT)} ({corridor}/{args.dir}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
