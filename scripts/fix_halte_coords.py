#!/usr/bin/env python3
"""Audit & repair stop coordinates in `assets/halte.json`.

Why this exists
---------------
The bundled stop list was assembled by hand, so some rows ended up sharing one
coordinate: a whole block of stops collapsed onto a single point (in K3, nine
stops sit on the same lat/lng, and another six do the same at the other end).
That breaks `HalteTracker`: the cumulative distance between consecutive stops is
0 m, the projection step has no segment to work with, and the map draws one
marker for nine stops.

What this script does
---------------------
For one corridor direction:

1. Projects every stop onto the corridor polyline from
   `assets/corridor_routes.json` (arc length + perpendicular offset).
2. Flags "collapsed clusters": consecutive stops on the same spot
   (< 25 m apart).
3. Re-resolves each stop in this order of confidence:
      a. `scripts/data/halte_overrides.json` — hand-checked, carries a `source`;
      b. route termini are pinned to the polyline endpoints;
      c. a surveyed OSM `highway=bus_stop` node whose name matches
         (snapshot `scripts/data/osm_halte_padang.json`, (c) OpenStreetMap, ODbL);
      d. the same stop name in another corridor that is not itself collapsed
         ("consensus" — the old-town stops exist in K2/K5 with distinct
         coordinates);
      e. even spacing along the corridor between the two nearest anchors
         (reported as `interpolated` — needs a field check).
4. Snaps a stop back onto the road when it is within 60 m of it.

Everything else is left untouched, so a run is a small, reviewable diff.

Usage
-----
    python scripts/fix_halte_coords.py --corridor K3                    # audit
    python scripts/fix_halte_coords.py --corridor K3 --apply            # rewrite
    python scripts/fix_halte_coords.py --corridor K3 --report docs/x.md

Koridor di `MANUAL_CORRIDORS` (saat ini K3) dilewati karena daftar haltesnya
disurvey manual di `scripts/data/manual/`; pakai `--force` bila memang mau
menimpanya dengan heuristik.
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HALTE_PATH = ROOT / "assets" / "halte.json"
ROUTES_PATH = ROOT / "assets" / "corridor_routes.json"
OSM_PATH = ROOT / "scripts" / "data" / "osm_halte_padang.json"
OVERRIDES_PATH = ROOT / "scripts" / "data" / "halte_overrides.json"

EARTH_R = 6371008.8
COLLAPSE_M = 25.0      # stops closer than this count as one collapsed point
MIN_GAP_M = 18.0       # two consecutive stops must be at least this far apart
MAX_OFFSET_M = 60.0    # never move a stop further than this from the corridor
OSM_GAP_M = 250.0      # max jump when trusting an OSM node for a placed stop
CONSENSUS_GAP_M = 900.0  # max jump when borrowing a coordinate from a corridor

# Koridor yang daftar haltesnya dirawat manual (survey lapangan). Heuristik di
# skrip ini tidak boleh menimpanya; sumbernya `scripts/data/manual/`.
MANUAL_CORRIDORS = {"K3"}

STOPWORDS = {
    "halte", "halter", "bus", "stop", "stasiun", "terminal", "padang",
    "kota", "sumatera", "barat", "sumbar", "i", "ii", "1", "2",
}
EXPAND = {
    "simp": "simpang", "simp.": "simpang", "sp": "simpang",
    "univ": "universitas", "univ.": "universitas", "university": "universitas",
    "sd": "sdn", "smp": "smpn", "jl": "jalan", "jl.": "jalan",
    "rs": "rumah sakit", "rsi": "rumah sakit", "rsud": "rumah sakit",
}


# --------------------------------------------------------------------------- #
# geometry
# --------------------------------------------------------------------------- #
def haversine(a: tuple[float, float], b: tuple[float, float]) -> float:
    lat1, lon1 = math.radians(a[0]), math.radians(a[1])
    lat2, lon2 = math.radians(b[0]), math.radians(b[1])
    dlat, dlon = lat2 - lat1, lon2 - lon1
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 2 * EARTH_R * math.asin(math.sqrt(h))


class Polyline:
    """Corridor path with cumulative arc lengths and point projection."""

    def __init__(self, points: list[list[float]]) -> None:
        self.pts = [(float(p[0]), float(p[1])) for p in points]
        self.cum = [0.0]
        for i in range(1, len(self.pts)):
            self.cum.append(self.cum[-1] + haversine(self.pts[i - 1], self.pts[i]))
        self.length = self.cum[-1]

    def project(self, p: tuple[float, float]) -> tuple[float, float, tuple[float, float]]:
        """(arc_length, perpendicular_offset_m, snapped_point) of the closest vertex."""
        best = (0.0, float("inf"), self.pts[0])
        for i in range(len(self.pts) - 1):
            a, b = self.pts[i], self.pts[i + 1]
            seg = self.cum[i + 1] - self.cum[i]
            if seg <= 0:
                continue
            kx = math.cos(math.radians(a[0]))
            ax, ay = a[1] * kx, a[0]
            bx, by = b[1] * kx, b[0]
            px, py = p[1] * kx, p[0]
            dx, dy = bx - ax, by - ay
            t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
            q = (a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]))
            d = haversine(p, q)
            if d < best[1]:
                best = (self.cum[i] + t * seg, d, q)
        return best

    def project_after(
        self, p: tuple[float, float], min_arc: float, tolerance: float = 60.0
    ) -> tuple[float, float, tuple[float, float]]:
        """Project onto the part of the path at/after `min_arc`.

        The recorded traces double back on themselves (U-turns, loops), so the
        globally nearest vertex can belong to the wrong pass. Constraining the
        search keeps the stops in driving order.
        """
        best: tuple[float, float, tuple[float, float]] | None = None
        for i in range(len(self.pts) - 1):
            seg = self.cum[i + 1] - self.cum[i]
            if seg <= 0 or self.cum[i + 1] < min_arc - tolerance:
                continue
            a, b = self.pts[i], self.pts[i + 1]
            kx = math.cos(math.radians(a[0]))
            ax, ay = a[1] * kx, a[0]
            bx, by = b[1] * kx, b[0]
            px, py = p[1] * kx, p[0]
            dx, dy = bx - ax, by - ay
            t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
            q = (a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]))
            d = haversine(p, q)
            if best is None or d < best[1]:
                best = (self.cum[i] + t * seg, d, q)
        return best if best is not None else self.project(p)

    def at(self, arc: float) -> tuple[float, float]:
        arc = max(0.0, min(self.length, arc))
        lo, hi = 0, len(self.cum) - 1
        while lo < hi - 1:
            mid = (lo + hi) // 2
            if self.cum[mid] <= arc:
                lo = mid
            else:
                hi = mid
        seg = self.cum[hi] - self.cum[lo]
        if seg <= 0:
            return self.pts[lo]
        t = (arc - self.cum[lo]) / seg
        a, b = self.pts[lo], self.pts[hi]
        return (a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]))


# --------------------------------------------------------------------------- #
# name matching
# --------------------------------------------------------------------------- #
def normalize(name: str) -> set[str]:
    s = unicodedata.normalize("NFKD", (name or "")).lower()
    s = s.replace("&", " ").replace("/", " ").replace("-", " ")
    s = "".join(ch if (ch.isalnum() or ch == " ") else " " for ch in s)
    tokens: list[str] = []
    for raw in s.split():
        for part in EXPAND.get(raw, raw).split():
            if part and part not in STOPWORDS:
                tokens.append(part)
    return set(tokens)


def _token_match(a: str, b: str) -> bool:
    if a == b:
        return True
    short, long = sorted((a, b), key=len)
    return len(short) >= 5 and long.startswith(short)


def name_score(a: str, b: str) -> float:
    ta, tb = normalize(a), normalize(b)
    if not ta or not tb:
        return 0.0
    hits = sum(1 for x in ta if any(_token_match(x, y) for y in tb))
    if hits == 0:
        return 0.0
    return hits / len(ta | tb)


# --------------------------------------------------------------------------- #
# data
# --------------------------------------------------------------------------- #
@dataclass
class Candidate:
    pos: tuple[float, float]
    source: str
    note: str = ""


@dataclass
class Fix:
    index: int
    name: str
    old: tuple[float, float]
    new: tuple[float, float]
    source: str
    note: str = ""
    collapsed: bool = False

    @property
    def moved(self) -> float:
        return haversine(self.old, self.new)


@dataclass
class DirectionAudit:
    arah: str
    fixes: list[Fix] = field(default_factory=list)
    poly_length: float = 0.0


def load_json_allow_bom(path: Path):
    return json.loads(path.read_bytes().decode("utf-8-sig"))


def load_osm() -> list[tuple[int, str, tuple[float, float]]]:
    out = []
    for el in load_json_allow_bom(OSM_PATH).get("elements", []):
        tags = el.get("tags") or {}
        name = tags.get("name")
        if name and "lat" in el:
            out.append((el["id"], name, (el["lat"], el["lon"])))
    return out


def load_overrides() -> dict[str, dict]:
    if not OVERRIDES_PATH.exists():
        return {}
    raw = load_json_allow_bom(OVERRIDES_PATH)
    out: dict[str, dict] = {}
    for cor, directions in raw.items():
        if cor.startswith("_"):
            continue
        for arah, rows in directions.items():
            for row in rows:
                out[f"{cor}|{arah}|{row['nama']}"] = row
    return out


def collapsed_flags(stops: list[dict]) -> list[bool]:
    flags = [False] * len(stops)
    for i in range(1, len(stops)):
        a = (float(stops[i - 1]["lat"]), float(stops[i - 1]["lng"]))
        b = (float(stops[i]["lat"]), float(stops[i]["lng"]))
        if haversine(a, b) < COLLAPSE_M:
            flags[i] = flags[i - 1] = True
    return flags


def project_sequence(
    poly: Polyline, stops: list[dict], flags: list[bool]
) -> list[tuple[float, float, tuple[float, float]]]:
    """Project the stops in driving order, not by nearest-vertex.

    Recorded traces double back (U-turns, loops), so the globally nearest vertex
    of a stop can belong to the wrong pass and produce a backwards arc length.
    Each stop is therefore projected onto the part of the path at/after the
    previous one.
    """
    out: list[tuple[float, float, tuple[float, float]]] = []
    last_arc = 0.0
    for i, stop in enumerate(stops):
        pos = (float(stop["lat"]), float(stop["lng"]))
        res = poly.project_after(pos, last_arc) if not flags[i] else poly.project(pos)
        out.append(res)
        last_arc = max(last_arc, res[0])
    return out


def build_consensus(halte: dict, corridor: str) -> dict[str, list[tuple[float, float, str]]]:
    """Same stop name in other corridors, ignoring rows that are collapsed."""
    table: dict[str, list[tuple[float, float, str]]] = {}
    for cor, block in halte.items():
        for arah, sub in block["arah"].items():
            stops = sub["halte"]
            bad = collapsed_flags(stops)
            for i, stop in enumerate(stops):
                if bad[i]:
                    continue
                key = "|".join(sorted(normalize(stop["nama"])))
                if not key:
                    continue
                table.setdefault(key, []).append(
                    (float(stop["lat"]), float(stop["lng"]), f"{cor}/{arah}")
                )
    return table


# --------------------------------------------------------------------------- #
# core
# --------------------------------------------------------------------------- #
def resolve_direction(
    corridor: str,
    arah: str,
    stops: list[dict],
    poly: Polyline,
    osm: list[tuple[int, str, tuple[float, float]]],
    overrides: dict[str, dict],
    consensus: dict[str, list[tuple[float, float, str]]],
) -> DirectionAudit:
    audit = DirectionAudit(arah=arah, poly_length=poly.length)
    flags = collapsed_flags(stops)
    proj = project_sequence(poly, stops, flags)
    resolved: dict[int, Candidate] = {}

    for i, stop in enumerate(stops):
        name = stop["nama"]
        old = (float(stop["lat"]), float(stop["lng"]))
        is_end = i == 0 or i == len(stops) - 1

        row = overrides.get(f"{corridor}|{arah}|{name}")
        if row:
            note = row.get("source", "")
            if row.get("needs_field_check"):
                note += " | PERLU CEK LAPANGAN"
            resolved[i] = Candidate((float(row["lat"]), float(row["lng"])), "override", note)
            continue

        if is_end:
            resolved[i] = Candidate(
                poly.pts[0] if i == 0 else poly.pts[-1], "terminus",
                "dipatok ke ujung polyline koridor",
            )
            continue

        # Nothing is provably wrong here: it sits on the road, so leave the
        # hand-placed value alone.
        if not flags[i] and proj[i][1] <= MAX_OFFSET_M:
            resolved[i] = Candidate(old, "unchanged", "")
            continue

        # OSM surveyed bus stop
        best_osm = None
        for osm_id, osm_name, pos in osm:
            score = name_score(name, osm_name)
            if score < 0.55:
                continue
            _, offset, _ = poly.project(pos)
            if offset > MAX_OFFSET_M:
                continue
            gap = haversine(old, pos)
            rank = (score, -gap)
            if best_osm is None or rank > best_osm[0]:
                best_osm = (rank, osm_id, osm_name, pos)
        if best_osm:
            _, osm_id, osm_name, pos = best_osm
            resolved[i] = Candidate(pos, f"osm:{osm_id}", f"node OSM '{osm_name}'")
            continue

        # same stop name in another corridor (not collapsed there)
        key = "|".join(sorted(normalize(name)))
        pool = [c for c in consensus.get(key, []) if not c[2].startswith(corridor + "/")]
        pool = [c for c in pool if haversine(old, (c[0], c[1])) <= CONSENSUS_GAP_M]
        if pool:
            lat, lng, where = min(pool, key=lambda c: haversine(old, (c[0], c[1])))
            resolved[i] = Candidate((lat, lng), f"konsensus:{where}", "koordinat dari koridor lain")
            continue

        # last resort: keep it on the road, and let the block below spread it
        resolved[i] = Candidate(proj[i][2], "pending", "")

    i = 0
    while i < len(stops):
        if resolved[i].source != "pending":
            i += 1
            continue
        j = i
        while j + 1 < len(stops) and resolved[j + 1].source == "pending":
            j += 1
        if i == j:
            # a lone stop: just put it on the corridor, do not invent a spot
            resolved[i] = Candidate(proj[i][2], "snapped", "digeser ke badan jalur koridor")
            i += 1
            continue
        start = proj[i - 1][0] if i > 0 else 0.0
        end = proj[j + 1][0] if j + 1 < len(stops) else poly.length
        if end <= start:
            end = min(poly.length, start + MIN_GAP_M * 3 * (j - i + 2))
        span = end - start
        for k, idx in enumerate(range(i, j + 1)):
            arc = start + span * (k + 1) / (j - i + 2)
            resolved[idx] = Candidate(
                poly.at(arc), "interpolated", "disebar merata di antara halte acuan"
            )
        i = j + 1

    for i, stop in enumerate(stops):
        old = (float(stop["lat"]), float(stop["lng"]))
        cand = resolved[i]
        new = cand.pos
        if cand.source == "unchanged" and haversine(old, new) < 3.0:
            new = old
        audit.fixes.append(Fix(i, stop["nama"], old, new, cand.source, cand.note, flags[i]))
    return audit


def validate(audit: DirectionAudit) -> list[str]:
    problems: list[str] = []
    for i in range(len(audit.fixes) - 1):
        a, b = audit.fixes[i], audit.fixes[i + 1]
        d = haversine(a.new, b.new)
        if d < MIN_GAP_M:
            problems.append(
                f"[{audit.arah}] #{a.index} '{a.name}' dan #{b.index} '{b.name}' "
                f"hanya {d:.0f} m"
            )
    return problems


NOTES = {
    "K3": [
        "Jejak GPS arah `pergi` baru dimulai di Jl. Samudra (-0.950221, 100.352161), "
        "sekitar 1,2 km setelah terminus sebenarnya di Jl. Hasanuddin. Sembilan halte "
        "pertama karena itu berada di luar garis jalur yang digambar peta — posisinya "
        "benar, tapi polyline `corridor_routes.json` arah pergi belum mencakup blok itu. "
        "Perlu rekam ulang jejak arah pergi untuk segmen tersebut.",
        "Urutan halte di blok pusat kota (Pasar Raya → Simp. Dobi → Museum Adityawarman → "
        "Mr. DIY → Plan B → Masjid Al Hakim → Gedung Joang 45) belum mengikuti jalan: "
        "Museum Adityawarman berada ~500 m di utara Mr. DIY, jadi rute urutannya belum "
        "monoton. Koordinat sudah benar, urutannya yang masih perlu diputuskan.",
    ],
}


def render_report(corridor: str, audits: list[DirectionAudit], problems: list[str]) -> str:
    total = sum(len(a.fixes) for a in audits)
    changed = [f for a in audits for f in a.fixes if f.moved >= 3.0]
    flagged = [f for a in audits for f in a.fixes if "CEK LAPANGAN" in f.note]
    collapsed = [f for a in audits for f in a.fixes if f.collapsed]
    out = [f"# Audit koordinat halte {corridor}", ""]
    out.append("## Temuan")
    out.append("")
    if collapsed:
        blocks = []
        run: list[Fix] = []
        for a in audits:
            for f in a.fixes:
                if f.collapsed:
                    run.append(f)
                elif run:
                    blocks.append((a.arah, run))
                    run = []
            if run:
                blocks.append((a.arah, run))
                run = []
        out.append(
            f"- **{len(collapsed)} halte** menempati koordinat yang sama dengan "
            f"tetangganya, sehingga membentuk {len(blocks)} blok tumpang tindih:"
        )
        for arah, run in blocks:
            names = ", ".join(f.name for f in run)
            out.append(f"  - `{arah}` #{run[0].index}–#{run[-1].index} ({len(run)} halte): {names}")
        out.append(
            "  Akibatnya `HalteTracker` tidak punya segmen untuk dihitung: jarak "
            "antartetangga 0 m dan peta menggambar satu penanda untuk banyak halte."
        )
        out.append("")
    out.append(
        "Sumber acuan, berurut menurut tingkat kepercayaan:\n\n"
        "1. `scripts/data/halte_overrides.json` — koordinat yang sudah dicek manual.\n"
        "2. Node `highway=bus_stop` OpenStreetMap (snapshot "
        "`scripts/data/osm_halte_padang.json`, data (c) kontributor OSM, lisensi ODbL).\n"
        "3. Nama halte yang sama di koridor lain (K1/K2/K5) yang tidak menumpuk.\n"
        "4. Penyebaran merata di sepanjang jalur koridor (`interpolated`).\n"
    )
    out.append(f"- Halte diperiksa: **{total}**")
    out.append(f"- Koordinat diubah (>= 3 m): **{len(changed)}**")
    out.append(f"- Perlu cek lapangan: **{len(flagged)}**")
    out.append("")
    if problems:
        out.append("## Peringatan")
        out += [f"- {p}" for p in problems]
        out.append("")
    if NOTES.get(corridor):
        out.append("## Catatan struktural")
        out.append("")
        out += [f"- {n}" for n in NOTES[corridor]]
        out.append("")
    if flagged:
        out.append("## Perlu cek lapangan")
        out.append("")
        out.append("| Arah | Halte | Lat | Lng | Catatan |")
        out.append("|------|-------|-----|-----|---------|")
        for a in audits:
            for f in a.fixes:
                if "CEK LAPANGAN" in f.note:
                    out.append(
                        f"| {a.arah} | {f.name} | {f.new[0]:.6f} | {f.new[1]:.6f} | {f.note} |"
                    )
        out.append("")
    for audit in audits:
        out.append(f"## Arah `{audit.arah}` — jalur {audit.poly_length / 1000:.2f} km")
        out.append("")
        out.append("| # | Halte | Lat lama | Lng lama | Lat baru | Lng baru | Geser | Sumber |")
        out.append("|---|-------|----------|----------|----------|----------|-------|--------|")
        for f in audit.fixes:
            if f.moved < 3.0:
                continue
            src = f.source
            if f.note:
                src += f" — {f.note}"
            out.append(
                f"| {f.index} | {f.name} | {f.old[0]:.6f} | {f.old[1]:.6f} | "
                f"{f.new[0]:.6f} | {f.new[1]:.6f} | {f.moved:.0f} m | {src} |"
            )
        out.append("")
    return "\n".join(out)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--corridor", default="K3")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--report")
    ap.add_argument(
        "--force",
        action="store_true",
        help="jalankan juga untuk koridor yang datanya dirawat manual",
    )
    args = ap.parse_args(argv)

    corridor = args.corridor.strip().upper()
    args.corridor = corridor
    if corridor in MANUAL_CORRIDORS and not args.force:
        print(
            f"{corridor} dirawat manual: sumbernya scripts/data/manual/"
            f"{corridor}_pergi.txt dan {corridor}_pulang.txt, diimpor dengan "
            "scripts/import_halte_txt.py.\n"
            "Skrip ini tidak menyentuhnya supaya koordinat survey tidak "
            "tertimpa nilai interpolasi/OSM. Pakai --force bila memang mau.",
            file=sys.stderr,
        )
        return 2

    halte = load_json_allow_bom(HALTE_PATH)
    routes = load_json_allow_bom(ROUTES_PATH)
    if args.corridor not in halte:
        print(f"koridor {args.corridor} tidak ada", file=sys.stderr)
        return 2

    osm = load_osm()
    overrides = load_overrides()
    consensus = build_consensus(halte, args.corridor)

    audits: list[DirectionAudit] = []
    problems: list[str] = []
    for arah, block in halte[args.corridor]["arah"].items():
        poly = Polyline(routes[args.corridor][arah])
        audit = resolve_direction(
            args.corridor, arah, block["halte"], poly, osm, overrides, consensus
        )
        audits.append(audit)
        problems += validate(audit)

    for audit in audits:
        moved = [f for f in audit.fixes if f.moved >= 3.0]
        print(f"{args.corridor}/{audit.arah}: {len(audit.fixes)} halte, {len(moved)} diubah")
        for f in moved:
            print(
                f"  #{f.index:2d} {f.name[:28]:28s} "
                f"{f.old[0]:.6f},{f.old[1]:.6f} -> {f.new[0]:.6f},{f.new[1]:.6f} "
                f"({f.moved:4.0f} m, {f.source})"
            )
    if problems:
        print("\nPERINGATAN:")
        for p in problems:
            print("  -", p)

    if args.report:
        path = Path(args.report)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(render_report(args.corridor, audits, problems), encoding="utf-8")
        print(f"\nreport -> {path}")

    if args.apply:
        backup = HALTE_PATH.with_suffix(".json.bak")
        shutil.copy2(HALTE_PATH, backup)
        for audit in audits:
            block = halte[args.corridor]["arah"][audit.arah]["halte"]
            for f in audit.fixes:
                block[f.index]["lat"] = round(f.new[0], 6)
                block[f.index]["lng"] = round(f.new[1], 6)
        HALTE_PATH.write_text(
            json.dumps(halte, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
        )
        print(f"applied -> {HALTE_PATH} (backup {backup.name})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
