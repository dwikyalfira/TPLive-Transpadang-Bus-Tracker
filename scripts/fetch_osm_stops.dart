// Ambil halte dari OpenStreetMap (Overpass) dan cocokkan dengan data lokal.
// Skrip pengembangan — tidak ikut build aplikasi, dan **tidak pernah** menimpa
// `assets/halte.json`.
//
//   dart run scripts/fetch_osm_stops.dart
//
// Hasil: `tools/halte_candidates.csv` untuk direview manual di atas citra
// satelit, lalu disalin ke `scripts/data/halte_overrides.json` bila disetujui.
//
// Catatan: mirror Overpass sering 502/timeout, jadi tiap endpoint dicoba
// bergantian dengan retry + backoff. Hasil query disimpan di
// `tools/osm_stops.json` supaya review bisa diulang tanpa jaringan.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const List<String> _endpoints = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
];

/// Bounding box Kota Padang (selatan, barat, utara, timur).
const String _bbox = '-1.10,100.25,-0.75,100.55';

const String _query = '''
[out:json][timeout:60];
(
  node["highway"="bus_stop"]($_bbox);
  node["public_transport"="platform"]($_bbox);
  node["amenity"="bus_station"]($_bbox);
  way["public_transport"="platform"]($_bbox);
);
out center tags;
''';

const double _earthR = 6371008.8;

/// Jarak maksimum (m) sebuah node OSM dianggap halte yang sama.
const double _matchMaxMeters = 150;

class _OsmStop {
  final int id;
  final String name;
  final double lat;
  final double lng;
  const _OsmStop(this.id, this.name, this.lat, this.lng);
}

class _LocalStop {
  final String id;
  final String corridor;
  final String direction;
  final String name;
  final double lat;
  final double lng;
  const _LocalStop(
      this.id, this.corridor, this.direction, this.name, this.lat, this.lng);
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

const Set<String> _stopwords = {
  'halte', 'halter', 'bus', 'stop', 'stasiun', 'terminal', 'padang',
  'kota', 'sumatera', 'barat', 'sumbar', 'raya', 'i', 'ii',
};

Set<String> _tokens(String name) {
  final cleaned = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty && !_stopwords.contains(t));
  return cleaned.toSet();
}

bool _tokenMatch(String a, String b) {
  if (a == b) return true;
  final short = a.length <= b.length ? a : b;
  final long = a.length <= b.length ? b : a;
  return short.length >= 5 && long.startsWith(short);
}

/// Skor 0..1: porsi token yang sama di antara dua nama.
double _nameScore(String a, String b) {
  final ta = _tokens(a);
  final tb = _tokens(b);
  if (ta.isEmpty || tb.isEmpty) return 0;
  final hits = ta.where((x) => tb.any((y) => _tokenMatch(x, y))).length;
  if (hits == 0) return 0;
  return hits / (ta.length + tb.length - hits);
}

Future<String> _post(String endpoint, String body) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.postUrl(Uri.parse(endpoint));
    request.headers
      ..set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded')
      ..set(HttpHeaders.userAgentHeader, 'TPLive-dev/1.0 (halte audit)');
    request.write('data=${Uri.encodeComponent(body)}');
    final response = await request.close().timeout(const Duration(seconds: 90));
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}: ${text.substring(0, math.min(120, text.length))}');
    }
    return text;
  } finally {
    client.close(force: true);
  }
}

/// Menjalankan query ke semua mirror dengan retry + backoff.
Future<String> _fetchOverpass() async {
  Object? lastError;
  for (var attempt = 0; attempt < 3; attempt++) {
    for (final endpoint in _endpoints) {
      try {
        stdout.writeln('Overpass: $endpoint (percobaan ${attempt + 1})');
        final text = await _post(endpoint, _query);
        if (text.trimLeft().startsWith('{')) return text;
        lastError = 'balasan bukan JSON dari $endpoint';
      } catch (error) {
        lastError = error;
        stdout.writeln('  gagal: $error');
      }
    }
    final wait = Duration(seconds: 3 * (attempt + 1));
    stdout.writeln('  menunggu ${wait.inSeconds}s sebelum mencoba lagi');
    await Future<void>.delayed(wait);
  }
  throw StateError('Semua mirror Overpass gagal: $lastError');
}

List<_OsmStop> _parseOsm(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final elements = (json['elements'] as List?) ?? const [];
  final out = <_OsmStop>[];
  for (final element in elements) {
    final map = element as Map<String, dynamic>;
    final tags = (map['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final name = (tags['name'] ?? '').toString().trim();
    if (name.isEmpty) continue;
    final lat = (map['lat'] as num?)?.toDouble() ??
        ((map['center'] as Map?)?['lat'] as num?)?.toDouble();
    final lng = (map['lon'] as num?)?.toDouble() ??
        ((map['center'] as Map?)?['lon'] as num?)?.toDouble();
    if (lat == null || lng == null) continue;
    out.add(_OsmStop((map['id'] as num).toInt(), name, lat, lng));
  }
  return out;
}

List<_LocalStop> _parseLocal(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final out = <_LocalStop>[];
  json.forEach((corridor, block) {
    final directions = (block as Map<String, dynamic>)['arah'] as Map<String, dynamic>;
    directions.forEach((direction, value) {
      for (final h in (value as Map<String, dynamic>)['halte'] as List) {
        final map = h as Map<String, dynamic>;
        out.add(_LocalStop(
          (map['id'] ?? '').toString(),
          corridor,
          direction,
          (map['nama'] ?? '').toString(),
          (map['lat'] as num).toDouble(),
          (map['lng'] as num).toDouble(),
        ));
      }
    });
  });
  return out;
}

String _csvCell(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

Future<void> main() async {
  Directory('tools').createSync(recursive: true);
  final cache = File('tools/osm_stops.json');

  String raw;
  if (cache.existsSync()) {
    stdout.writeln('Memakai cache ${cache.path} (hapus untuk query ulang).');
    raw = cache.readAsStringSync();
  } else {
    raw = await _fetchOverpass();
    cache.writeAsStringSync(raw);
  }

  final osm = _parseOsm(raw);
  final local = _parseLocal(_readJson('assets/halte.json'));
  stdout.writeln('Node OSM: ${osm.length}, halte lokal: ${local.length}');

  final rows = <String>[];
  var updated = 0;
  for (final stop in local) {
    _OsmStop? best;
    var bestScore = 0.0;
    var bestDistance = double.infinity;
    for (final candidate in osm) {
      final distance = _haversine(stop.lat, stop.lng, candidate.lat, candidate.lng);
      if (distance > _matchMaxMeters) continue;
      final score = _nameScore(stop.name, candidate.name);
      if (score <= 0) continue;
      if (score > bestScore || (score == bestScore && distance < bestDistance)) {
        best = candidate;
        bestScore = score;
        bestDistance = distance;
      }
    }
    if (best == null) continue;
    updated++;
    rows.add([
      best.id.toString(),
      best.name,
      best.lat.toStringAsFixed(6),
      best.lng.toStringAsFixed(6),
      stop.id,
      stop.corridor,
      stop.direction,
      stop.name,
      stop.lat.toStringAsFixed(6),
      stop.lng.toStringAsFixed(6),
      bestScore.toStringAsFixed(2),
      bestDistance.toStringAsFixed(0),
    ].map(_csvCell).join(','));
  }

  final out = File('tools/halte_candidates.csv');
  out.writeAsStringSync(
    'osm_id,osm_name,osm_lat,osm_lng,halte_id,corridor,direction,halte_name,'
    'halte_lat,halte_lng,name_score,distance_m\n'
    '${rows.join('\n')}\n',
  );

  stdout.writeln('Kandidat cocok: $updated -> ${out.path}');
  stdout.writeln('Review manual dulu; skrip ini tidak mengubah assets/halte.json.');
}
