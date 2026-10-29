// Rapikan geometri jalur koridor yang "spaghetti" (jalur bolak-balik /
// mengulang ruas yang sama) dengan menyusun ulang jalur sebagai rangkaian
// sub-jalur TERPENDEK antar halte berurutan.
//
//   dart run scripts/clean_corridor_routes.dart            # lihat pratinjau
//   dart run scripts/clean_corridor_routes.dart --write     # tulis hasilnya
//
// Cara kerja singkat:
// 1. titik jalur dianggap simpul graf; sisi = titik berurutan (bobot = jarak);
// 2. ditambah "jalan pintas" antara dua titik yang berdekatan (<= 25 m) tetapi
//    berjauhan di dalam urutan — inilah yang memungkinkan lompatan melewati
//    bagian yang mengulang;
// 3. untuk setiap pasangan halte berurutan, dicari sub-jalur terpendek
//    (Dijkstra) antara proyeksi kedua halte, lalu disambung.
//
// Karena jalan pintas maksimal 25 m, jalur hasil tidak pernah "melompat" jauh
// — aman untuk digambar di peta. Setiap halte tetap berada di jalur (proyeksi
// tiap halte dipakai sebagai titik sambung), dan urutan halte dijamin naik.
//
// Hasil ditulis ke `assets/corridor_routes.json` hanya untuk arah yang
// panjangnya menyusut >= [_minShrink] (artinya memang ada pengulangan) dan
// lolos pemeriksaan: rasio panjang jalur/halte di [_minRatio]..[_maxRatio],
// serta offset tiap halte ke jalur tidak memburuk.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Ambang jarak (m) dua titik dianggap "titik yang sama" (jalan pintas).
const double _linkMeters = 25;

/// Panjang minimum penyusutan agar hasil dianggap perbaikan.
const double _minShrink = 0.05;

/// Batas wajar rasio panjang jalur terhadap jumlah jarak antar-halte.
const double _minRatio = 0.7;
const double _maxRatio = 1.6;

/// Offset maksimum (m) sebuah halte terhadap jalur.
const double _maxOffsetMeters = 150;

const double _earthR = 6371008.8;

double _haversine(List<double> a, List<double> b) {
  final p1 = a[0] * math.pi / 180;
  final p2 = b[0] * math.pi / 180;
  final dp = (b[0] - a[0]) * math.pi / 180;
  final dl = (b[1] - a[1]) * math.pi / 180;
  final h = math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * _earthR * math.asin(math.sqrt(h));
}

double _length(List<List<double>> points) {
  var total = 0.0;
  for (var i = 0; i < points.length - 1; i++) {
    total += _haversine(points[i], points[i + 1]);
  }
  return total;
}

String _readText(String path) {
  var raw = File(path).readAsStringSync();
  if (raw.isNotEmpty && raw.codeUnitAt(0) == 0xFEFF) raw = raw.substring(1);
  return raw;
}

List<List<double>> _parsePoints(Object? raw) {
  final out = <List<double>>[];
  for (final item in (raw as List)) {
    final pair = item as List;
    out.add([
      (pair[0] as num).toDouble(),
      (pair[1] as num).toDouble(),
    ]);
  }
  return out;
}

/// Graf jalur: sisi berurutan + jalan pintas pada titik yang berdekatan.
class _Graph {
  final List<List<(int, double)>> adjacency;

  const _Graph(this.adjacency);

  factory _Graph.build(List<List<double>> points) {
    final n = points.length;
    final adjacency = List.generate(n, (_) => <(int, double)>[]);
    for (var i = 0; i < n - 1; i++) {
      final w = _haversine(points[i], points[i + 1]);
      adjacency[i].add((i + 1, w));
      adjacency[i + 1].add((i, w));
    }

    // Hash spasial: sel ~55 m supaya pencarian tetangga cukup 3x3 sel.
    const cell = 0.0005;
    final buckets = <String, List<int>>{};
    String key(int x, int y) => '$x:$y';
    for (var i = 0; i < n; i++) {
      final x = (points[i][0] / cell).round();
      final y = (points[i][1] / cell).round();
      buckets.putIfAbsent(key(x, y), () => <int>[]).add(i);
    }
    for (var i = 0; i < n; i++) {
      final cx = (points[i][0] / cell).round();
      final cy = (points[i][1] / cell).round();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final j in buckets[key(cx + dx, cy + dy)] ?? const <int>[]) {
            // Lewati tetangga dekat dalam urutan (sudah tersambung).
            if (j <= i + 5) continue;
            final d = _haversine(points[i], points[j]);
            if (d > _linkMeters) continue;
            adjacency[i].add((j, d));
            adjacency[j].add((i, d));
          }
        }
      }
    }
    return _Graph(adjacency);
  }

  /// Dijkstra sederhana (graf kecil, tanpa prioritas queue khusus).
  List<int>? shortestPath(int from, int to) {
    final n = adjacency.length;
    final dist = List<double>.filled(n, double.infinity);
    final prev = List<int>.filled(n, -1);
    final done = List<bool>.filled(n, false);
    dist[from] = 0;

    while (true) {
      var best = -1;
      var bestD = double.infinity;
      for (var i = 0; i < n; i++) {
        if (!done[i] && dist[i] < bestD) {
          bestD = dist[i];
          best = i;
        }
      }
      if (best < 0 || best == to) break;
      done[best] = true;
      for (final (next, weight) in adjacency[best]) {
        final nd = dist[best] + weight;
        if (nd < dist[next]) {
          dist[next] = nd;
          prev[next] = best;
        }
      }
    }

    if (dist[to].isInfinite) return null;
    final path = <int>[to];
    while (path.last != from) {
      final p = prev[path.last];
      if (p < 0) return null;
      path.add(p);
    }
    return path.reversed.toList();
  }
}

int _nearestIndex(List<List<double>> points, List<double> target) {
  var best = 0;
  var bestD = double.infinity;
  for (var i = 0; i < points.length; i++) {
    final d = _haversine(target, points[i]);
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best;
}

double _offset(List<List<double>> points, List<double> target) {
  var best = double.infinity;
  for (final p in points) {
    final d = _haversine(target, p);
    if (d < best) best = d;
  }
  return best;
}

/// Hasil pembersihan satu arah.
class _CleanResult {
  final List<List<double>> points;
  final double beforeKm;
  final double afterKm;
  final double stopKm;
  final double maxOffsetMeters;
  final bool stopsMonotonic;

  const _CleanResult({
    required this.points,
    required this.beforeKm,
    required this.afterKm,
    required this.stopKm,
    required this.maxOffsetMeters,
    required this.stopsMonotonic,
  });

  double get ratio => stopKm == 0 ? 0 : afterKm / stopKm;
}

_CleanResult _clean(
  List<List<double>> points,
  List<List<double>> stops,
) {
  final graph = _Graph.build(points);
  final projections = [for (final s in stops) _nearestIndex(points, s)];
  var monotonic = true;
  for (var i = 0; i < projections.length - 1; i++) {
    if (projections[i] > projections[i + 1]) monotonic = false;
  }

  final chain = <int>[];
  for (var i = 0; i < projections.length - 1; i++) {
    var a = projections[i];
    var b = projections[i + 1];
    if (b < a) {
      final t = a;
      a = b;
      b = t;
    }
    final path = graph.shortestPath(a, b);
    if (path == null) continue;
    final start = (chain.isNotEmpty && chain.last == path.first) ? 1 : 0;
    chain.addAll(path.sublist(start));
  }

  final cleaned = chain.isEmpty
      ? points
      : [for (final i in chain) points[i]];

  var maxOffset = 0.0;
  for (final s in stops) {
    final d = _offset(cleaned, s);
    if (d > maxOffset) maxOffset = d;
  }

  return _CleanResult(
    points: cleaned,
    beforeKm: _length(points) / 1000,
    afterKm: _length(cleaned) / 1000,
    stopKm: _stopsLength(stops) / 1000,
    maxOffsetMeters: maxOffset,
    stopsMonotonic: monotonic,
  );
}

double _stopsLength(List<List<double>> stops) {
  var total = 0.0;
  for (var i = 0; i < stops.length - 1; i++) {
    total += _haversine(stops[i], stops[i + 1]);
  }
  return total;
}

List<List<double>> _stopPoints(Map<String, dynamic> halteJson, String corridor,
    String direction) {
  final block = halteJson[corridor] as Map<String, dynamic>;
  final arah = block['arah'] as Map<String, dynamic>;
  final dir = arah[direction] as Map<String, dynamic>;
  final out = <List<double>>[];
  for (final h in dir['halte'] as List) {
    final map = h as Map<String, dynamic>;
    out.add([
      (map['lat'] as num).toDouble(),
      (map['lng'] as num).toDouble(),
    ]);
  }
  return out;
}

void main(List<String> args) {
  final write = args.contains('--write');

  final routesFile = File('assets/corridor_routes.json');
  final routes = jsonDecode(_readText(routesFile.path)) as Map<String, dynamic>;
  final halte =
      jsonDecode(_readText('assets/halte.json')) as Map<String, dynamic>;

  stdout.writeln(
      '${'koridor/arah'.padRight(14)} ${'sebelum'.padLeft(9)} ${'sesudah'.padLeft(9)} '
      '${'halte'.padLeft(8)} ${'rasio'.padLeft(6)} ${'offset'.padLeft(7)}  status');

  var changed = 0;
  for (final corridor in routes.keys.toList()) {
    final directions = routes[corridor] as Map<String, dynamic>;
    for (final direction in directions.keys.toList()) {
      final points = _parsePoints(directions[direction]);
      if (points.length < 2) continue;
      final stops = _stopPoints(halte, corridor, direction);
      if (stops.length < 2) continue;

      final result = _clean(points, stops);
      final shrink = 1 - result.afterKm / result.beforeKm;

      String status;
      if (shrink < _minShrink) {
        status = 'tetap';
      } else if (!result.stopsMonotonic) {
        status = 'DITOLAK (urutan halte tidak naik)';
      } else if (result.ratio < _minRatio || result.ratio > _maxRatio) {
        status = 'DITOLAK (rasio ${result.ratio.toStringAsFixed(2)})';
      } else if (result.maxOffsetMeters > _maxOffsetMeters) {
        status =
            'DITOLAK (offset ${result.maxOffsetMeters.toStringAsFixed(0)} m)';
      } else {
        status = 'dirapikan (-${(shrink * 100).toStringAsFixed(0)}%)';
        if (write) {
          directions[direction] = [
            for (final p in result.points)
              [
                double.parse(p[0].toStringAsFixed(6)),
                double.parse(p[1].toStringAsFixed(6)),
              ],
          ];
          changed++;
        }
      }

      stdout.writeln(
        '${'$corridor/$direction'.padRight(14)} '
        '${result.beforeKm.toStringAsFixed(1).padLeft(9)} '
        '${result.afterKm.toStringAsFixed(1).padLeft(9)} '
        '${result.stopKm.toStringAsFixed(1).padLeft(8)} '
        '${result.ratio.toStringAsFixed(2).padLeft(6)} '
        '${result.maxOffsetMeters.toStringAsFixed(0).padLeft(7)}  $status',
      );
    }
  }

  if (!write) {
    stdout.writeln('\nPratinjau saja. Jalankan dengan --write untuk menulis.');
    return;
  }
  routesFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(routes));
  stdout.writeln('\n$changed arah ditulis ke ${routesFile.path}.');
  stdout.writeln('Verifikasi: dart run scripts/audit_halte.dart');
}
