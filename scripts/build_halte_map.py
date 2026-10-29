#!/usr/bin/env python3
"""Build `docs/halte_k3_map.html`: a before/after map of the K3 stop fixes.

Reads the previous revision of `assets/halte.json` from git (`HEAD`), the
current file, and the K3 polylines, then writes a self-contained Leaflet page so
the corrections can be eyeballed against Google Maps or the real street.

    python scripts/build_halte_map.py
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "halte_k3_map.html"
CORRIDOR = "K3"


def load(path: Path):
    return json.loads(path.read_bytes().decode("utf-8-sig"))


def main() -> int:
    old = json.loads(
        subprocess.run(
            ["git", "show", f"HEAD:assets/halte.json"],
            cwd=ROOT, capture_output=True, check=True,
        ).stdout.decode("utf-8-sig")
    )
    new = load(ROOT / "assets" / "halte.json")
    routes = load(ROOT / "assets" / "corridor_routes.json")

    payload = {"corridor": CORRIDOR, "arah": {}}
    for arah in ("pergi", "pulang"):
        old_stops = old[CORRIDOR]["arah"][arah]["halte"]
        new_stops = new[CORRIDOR]["arah"][arah]["halte"]
        rows = []
        for i, (o, n) in enumerate(zip(old_stops, new_stops)):
            moved = abs(o["lat"] - n["lat"]) > 1e-6 or abs(o["lng"] - n["lng"]) > 1e-6
            rows.append({
                "i": i,
                "nama": n["nama"],
                "old": [o["lat"], o["lng"]],
                "new": [n["lat"], n["lng"]],
                "moved": moved,
            })
        payload["arah"][arah] = {
            "label": new[CORRIDOR]["arah"][arah].get("label", ""),
            "stops": rows,
            "poly": routes[CORRIDOR][arah],
        }

    html = TEMPLATE.replace("__DATA__", json.dumps(payload, ensure_ascii=False))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(html, encoding="utf-8")
    print(f"written -> {OUT}")
    return 0


TEMPLATE = r"""<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Audit koordinat halte K3 — TPLive</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<style>
  :root{
    --ink:#10161c; --ink-2:#39434e; --line:#dfe3e8; --bg:#f6f7f9;
    --brand:#f47f38; --bad:#d7263d; --ok:#1b998b;
  }
  *{box-sizing:border-box}
  html,body{margin:0;height:100%;font-family:"Segoe UI",Inter,system-ui,sans-serif;color:var(--ink)}
  body{display:flex;flex-direction:column;background:var(--bg)}
  header{padding:14px 20px;background:#111820;color:#fff;display:flex;gap:18px;align-items:baseline;flex-wrap:wrap}
  header h1{margin:0;font-size:16px;font-weight:600;letter-spacing:.2px}
  header p{margin:0;font-size:12.5px;color:#9aa6b2}
  main{flex:1;display:flex;min-height:0}
  #map{flex:1;min-height:0}
  aside{width:340px;border-left:1px solid var(--line);background:#fff;overflow:auto;padding:14px}
  .seg{display:flex;gap:6px;margin-bottom:12px}
  .seg button{flex:1;padding:7px 10px;border:1px solid var(--line);background:#fff;border-radius:8px;
    font:inherit;font-size:12.5px;cursor:pointer;color:var(--ink-2)}
  .seg button.on{background:var(--ink);color:#fff;border-color:var(--ink)}
  .legend{display:flex;gap:14px;font-size:12px;color:var(--ink-2);margin-bottom:12px;flex-wrap:wrap}
  .legend i{display:inline-block;width:10px;height:10px;border-radius:50%;margin-right:5px;vertical-align:middle}
  h2{font-size:12px;text-transform:uppercase;letter-spacing:.08em;color:#7a8794;margin:16px 0 8px}
  ul{list-style:none;margin:0;padding:0;font-size:12.5px}
  li{padding:7px 8px;border-radius:8px;display:flex;gap:8px;align-items:baseline}
  li:hover{background:#f2f4f7;cursor:pointer}
  li b{font-weight:600}
  li span{color:#7a8794;font-size:11.5px;margin-left:auto;white-space:nowrap}
  .chip{display:inline-block;font-size:10.5px;padding:1px 6px;border-radius:999px;background:#eef1f4;color:#5b6672}
  .chip.bad{background:#fdeaec;color:var(--bad)}
  .leaflet-popup-content{font-size:12.5px;line-height:1.5}
  .pop b{font-size:13px}
  .pop code{background:#f2f4f7;padding:1px 4px;border-radius:4px;font-size:11.5px}
</style>
</head>
<body>
<header>
  <h1>Audit koordinat halte K3</h1>
  <p>Titik abu = data lama · titik oranye = data baru · garis putus-putus = pergeseran</p>
</header>
<main>
  <div id="map"></div>
  <aside>
    <div class="seg" id="seg"></div>
    <div class="legend">
      <span><i style="background:#98a2ad"></i>lama</span>
      <span><i style="background:#f47f38"></i>baru</span>
      <span><i style="background:#1b998b"></i>tidak berubah</span>
    </div>
    <h2 id="count"></h2>
    <ul id="list"></ul>
  </aside>
</main>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
const DATA = __DATA__;
const map = L.map('map', {zoomControl:true}).setView([-0.912, 100.372], 13);
L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
  maxZoom: 19,
  attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
}).addTo(map);

let layer = L.layerGroup().addTo(map);
let current = 'pergi';

function dot(latlng, color, r, fill){
  return L.circleMarker(latlng, {
    radius:r, color:color, weight:2, fillColor:color, fillOpacity: fill ? .85 : .12
  });
}

function render(arah){
  current = arah;
  layer.clearLayers();
  const d = DATA.arah[arah];

  L.polyline(d.poly.map(p => [p[0], p[1]]), {
    color:'#2b6cb0', weight:3, opacity:.55
  }).addTo(layer);

  let changed = 0;
  d.stops.forEach(s => {
    if (s.moved){
      changed++;
      L.polyline([s.old, s.new], {color:'#d7263d', weight:1.6, dashArray:'4 4', opacity:.7}).addTo(layer);
      dot(s.old, '#98a2ad', 6, false).addTo(layer)
        .bindPopup(`<div class="pop"><b>${s.nama}</b><br><span class="chip bad">posisi lama</span><br>
          <code>${s.old[0].toFixed(6)}, ${s.old[1].toFixed(6)}</code></div>`);
      dot(s.new, '#f47f38', 7, true).addTo(layer)
        .bindPopup(`<div class="pop"><b>${s.nama}</b><br><span class="chip">posisi baru</span><br>
          <code>${s.new[0].toFixed(6)}, ${s.new[1].toFixed(6)}</code></div>`);
    } else {
      dot(s.new, '#1b998b', 5, true).addTo(layer).bindPopup(`<div class="pop"><b>${s.nama}</b><br>tidak berubah</div>`);
    }
  });

  document.getElementById('count').textContent =
    `${d.stops.length} halte · ${changed} diubah`;
  const ul = document.getElementById('list');
  ul.innerHTML = '';
  d.stops.filter(s => s.moved).forEach(s => {
    const li = document.createElement('li');
    const d2 = map.distance(s.old, s.new);
    li.innerHTML = `<b>${s.nama}</b><span>${d2 >= 1000 ? (d2/1000).toFixed(2)+' km' : Math.round(d2)+' m'}</span>`;
    li.onclick = () => map.setView(s.new, 17);
    ul.appendChild(li);
  });
  const seg = document.getElementById('seg');
  [...seg.children].forEach(b => b.classList.toggle('on', b.dataset.arah === arah));
}

const seg = document.getElementById('seg');
['pergi','pulang'].forEach(a => {
  const b = document.createElement('button');
  b.textContent = a === 'pergi' ? 'Arah pergi' : 'Arah pulang';
  b.dataset.arah = a;
  b.onclick = () => render(a);
  seg.appendChild(b);
});
render('pergi');

const all = Object.values(DATA.arah).flatMap(d => d.stops.flatMap(s => [s.old, s.new]));
map.fitBounds(L.latLngBounds(all).pad(0.08));
</script>
</body>
</html>
"""

if __name__ == "__main__":
    raise SystemExit(main())
