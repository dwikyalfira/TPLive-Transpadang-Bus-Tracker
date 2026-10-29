// Audit kualitas data halte. Skrip pengembangan — tidak ikut build aplikasi.
//
//   dart run scripts/audit_halte.dart
//
// Membaca `assets/halte.json` + `assets/corridor_routes.json`, lalu menulis
// `tools/halte_audit.csv` (satu baris per temuan) dan ringkasan ke stdout.
//
// Yang diperiksa:
//   dup-name      nama halte sama muncul lebih dari sekali di satu arah
//   same-pair     pasangan nama sama yang jaraknya > 150 m (kemungkinan salah
//                 koordinat, bukan sekadar sisi jalan yang berbeda)
//   backward      jarak posisi halte ke-i sepanjang jalur koridor lebih besar
//                 dari halte ke-(i+1) (urutan tidak mengikuti jalan)
//   zero-gap      dua halte berurutan berjarak < 25 m (blok menumpuk)
//   length-gap    panjang jalur koridor vs jumlah jarak antar-halte menyimpang
//                 lebih dari 30%
//   outside-bbox  koordinat di luar kotak Kota Padang

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const double _earthR = 6371008.8;

/// Kotak kasar Kota Padang; koordinat di luarnya hampir pasti salah.
const double _padangMinLat = -1.10;
const double _padangMaxLat = -0.75;
const double _padangMinLng = 100.25;
const double _padangMaxLng = 100.55;

class _Stop {
  final String id;
  final String name;
  final double lat;
  final double lng;
  const _Stop(this.id, this.name, this.lat, this.lng);
}

class _Finding {
  final String corridor;
  final String direction;
  final String kind;
  final String stopA;
  final String stopB;
  final String detail;
  final double value;

  const _Finding(
    this.corridor,
    this.direction,
    this.kind,
    this.stopA,
    this.stopB,
    this.detail,
    this.value,
  );

  String toCsv() => [
        corridor,
        direction,
        kind,
        stopA,
        stopB,
        detail,
        value.isFinite ? value.toStringAsFixed(1) : '',
      ].map(_csvCell).join(',');
}

String _csvCell(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

double _haversine(double lat1, double lng1, double lat2, double lng2) {
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dp = (lat2 - lat1) * math.pi / 180;
  final dl = (lng2 - lng1) * math.pi / 180;
  final h = math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * _earthR * math.asin(math.sqrt(h));
}

String _readJson(String path) {
  var raw = File(path).readAsStringSync();
  if (raw.isNotEmpty && raw.codeUnitAt(0) == 0xFEFF) raw = raw.substring(1);
  return raw;
}

/// Proyeksi titik ke polyline: (jarak sepanjang jalur, jarak tegak lurus).
(int, double, double) _project(
  double lat,
  double lng,
  List<List<double>> path,
) {
  var bestArc = 0.0;
  var bestOffset = double.infinity;
  var arc = 0.0;
  for (var i = 0; i < path.length - 1; i++) {
    final ax = path[i][1], ay = path[i][0];
    final bx = path[i + 1][1], by = path[i + 1][0];
    final seg = _haversine(ay, ax, by, bx);
    if (seg <= 0) continue;
    final kx = math.cos(ay * math.pi / 180);
    final dax = (ax * kx), day = ay;
    final dbx = (bx * kx), dby = by;
    final px = (lng * kx), py = lat;
    final dx = dbx - dax, dy = dby - day;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : ((px - dax) * dx + (py - day) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final qLat = ay + t * (by - ay);
    final qLng = ax + t * (bx - ax);
    final off = _haversine(lat, lng, qLat, qLng);
    if (off < bestOffset) {
      bestOffset = off;
      bestArc = arc + t * seg;
    }
    arc += seg;
  }
  return (0, bestArc, bestOffset);
}

double _pathLength(List<List<double>> path) {
  var total = 0.0;
  for (var i = 0; i < path.length - 1; i++) {
    total += _haversine(path[i][0], path[i][1], path[i + 1][0], path[i + 1][1]);
  }
  return total;
}

void main() {
  final halte = json.decode(_readJson('assets/halte.json')) as Map<String, dynamic>;
  final routes =
      json.decode(_readJson('assets/corridor_routes.json')) as Map<String, dynamic>;

  final findings = <_Finding>[];
  final stopsByCorridor = <String, int>{};

  for (final corridor in halte.keys) {
    final block = halte[corridor] as Map<String, dynamic>;
    final directions = block['arah'] as Map<String, dynamic>;
    for (final direction in directions.keys) {
      final raw = (directions[direction] as Map<String, dynamic>)['halte'] as List;
      final stops = <_Stop>[
        for (var i = 0; i < raw.length; i++)
          _Stop(
            ((raw[i] as Map)['id'] ?? '').toString(),
            ((raw[i] as Map)['nama'] ?? '').toString(),
            ((raw[i] as Map)['lat'] as num).toDouble(),
            ((raw[i] as Map)['lng'] as num).toDouble(),
          ),
      ];
      stopsByCorridor['$corridor/$direction'] = stops.length;

      // 1. nama ganda dalam satu arah
      final byName = <String, List<_Stop>>{};
      for (final s in stops) {
        byName.putIfAbsent(s.name.trim().toLowerCase(), () => []).add(s);
      }
      byName.forEach((name, group) {
        if (group.length > 1) {
          findings.add(_Finding(
            corridor,
            direction,
            'dup-name',
            group.map((s) => s.id).join(' '),
            '',
            '$name x${group.length}',
            group.length.toDouble(),
          ));
        }
        for (var i = 0; i < group.length - 1; i++) {
          final d = _haversine(group[i].lat, group[i].lng, group[i + 1].lat,
              group[i + 1].lng);
          if (d > 150) {
            findings.add(_Finding(
              corridor,
              direction,
              'same-pair',
              group[i].id,
              group[i + 1].id,
              name,
              d,
            ));
          }
        }
      });

      // 2. jarak berurutan + bbox
      for (var i = 0; i < stops.length; i++) {
        final s = stops[i];
        if (s.lat < _padangMinLat ||
            s.lat > _padangMaxLat ||
            s.lng < _padangMinLng ||
            s.lng > _padangMaxLng) {
          findings.add(_Finding(corridor, direction, 'outside-bbox', s.id, '',
              '${s.lat},${s.lng}', 0));
        }
        if (i == 0) continue;
        final prev = stops[i - 1];
        final d = _haversine(prev.lat, prev.lng, s.lat, s.lng);
        if (d < 25) {
          findings.add(_Finding(corridor, direction, 'zero-gap', prev.id, s.id,
              '${prev.name} -> ${s.name}', d));
        }
      }

      // 3. urutan mengikuti jalur + panjang jalur
      final pathRaw = ((routes[corridor] as Map<String, dynamic>?)?[direction])
          as List?;
      if (pathRaw == null) continue;
      final path = [
        for (final p in pathRaw) [((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()],
      ];
      var lastArc = 0.0;
      var sumGap = 0.0;
      for (var i = 0; i < stops.length; i++) {
        final (_, arc, offset) = _project(stops[i].lat, stops[i].lng, path);
        if (i > 0) {
          sumGap += _haversine(stops[i - 1].lat, stops[i - 1].lng, stops[i].lat,
              stops[i].lng);
        }
        if (i > 0 && arc < lastArc - 30) {
          findings.add(_Finding(corridor, direction, 'backward', stops[i].id,
              stops[i - 1].id, '${stops[i].name} (offset ${offset.toStringAsFixed(0)} m)',
              lastArc - arc));
        }
        if (arc > lastArc) lastArc = arc;
      }
      final pathLen = _pathLength(path);
      if (pathLen > 0 && sumGap > 0) {
        final ratio = sumGap / pathLen;
        if (ratio < 0.7 || ratio > 1.3) {
          findings.add(_Finding(corridor, direction, 'length-gap', '', '',
              'jalur ${(pathLen / 1000).toStringAsFixed(1)} km vs halte '
              '${(sumGap / 1000).toStringAsFixed(1)} km',
              ratio));
        }
      }
    }
  }

  Directory('tools').createSync(recursive: true);
  final out = File('tools/halte_audit.csv');
  final buffer = StringBuffer('corridor,direction,kind,stop_a,stop_b,detail,value\n');
  for (final f in findings) {
    buffer.writeln(f.toCsv());
  }
  out.writeAsStringSync(buffer.toString());

  stdout.writeln('Halte diperiksa:');
  stopsByCorridor.forEach((k, v) => stdout.writeln('  $k: $v'));
  stdout.writeln('');
  final byKind = <String, int>{};
  for (final f in findings) {
    byKind[f.kind] = (byKind[f.kind] ?? 0) + 1;
  }
  stdout.writeln('Temuan: ${findings.length}');
  byKind.forEach((k, v) => stdout.writeln('  $k: $v'));
  stdout.writeln('Laporan: ${out.path}');
}
