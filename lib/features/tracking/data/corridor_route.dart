import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// Direktori berkas GeoJSON koridor yang digambar manual (satu berkas per
/// koridor, mis. `K3.geojson`).
const String corridorRouteGeoJsonDir = 'assets/routes/';

/// Geometri jalur satu arah koridor (mengikuti jalan).
///
/// Sumbernya dua lapis:
/// 1. digambar manual di `assets/routes/*.geojson` (baca
///    [loadManualCorridorRouteDataset]);
/// 2. dibangkitkan sekali oleh `scripts/generate_corridor_routes.ps1` ke
///    `assets/corridor_routes.json` (baca [loadCorridorRouteDataset]).
class CorridorRouteDataset {
  /// kode koridor (huruf besar) -> arah (`pergi`/`pulang`) -> titik jalur.
  final Map<String, Map<String, List<LatLng>>> corridors;

  const CorridorRouteDataset(this.corridors);

  /// Titik jalur untuk [corridor] + [directionKey], atau null bila tidak
  /// tersedia (pemanggil memakai garis lurus antar-halte sebagai cadangan).
  List<LatLng>? points(String corridor, String directionKey) {
    final directions = corridors[corridor.trim().toUpperCase()];
    final points = directions?[directionKey.trim().toLowerCase()];
    if (points == null || points.length < 2) return null;
    return points;
  }
}

/// Menumpuk geometri [overlay] di atas [base].
///
/// Arah yang punya geometri di [overlay] (minimal dua titik) menang; sisanya
/// memakai [base]. Dipakai supaya gambar manual mengalahkan hasil routing,
/// tapi koridor yang belum digambar tetap punya garis.
CorridorRouteDataset overlayRouteGeometry(
  CorridorRouteDataset? overlay,
  CorridorRouteDataset? base,
) {
  if (overlay == null) return base ?? const CorridorRouteDataset({});
  if (base == null) return overlay;

  final merged = <String, Map<String, List<LatLng>>>{};
  base.corridors.forEach((kode, directions) {
    merged[kode] = Map<String, List<LatLng>>.of(directions);
  });
  overlay.corridors.forEach((kode, directions) {
    final target = merged.putIfAbsent(kode, () => <String, List<LatLng>>{});
    directions.forEach((arah, points) {
      if (points.length >= 2) target[arah] = points;
    });
  });
  return CorridorRouteDataset(merged);
}

/// Membaca geometri koridor dari GeoJSON `FeatureCollection` (RFC 7946: urutan
/// koordinat `[lng, lat]`, dikembalikan sebagai [LatLng] `[lat, lng]`).
///
/// Setiap fitur `LineString` wajib memuat properti `corridor` dan `direction`.
/// Fitur yang tidak lengkap, geometrinya bukan `LineString`, atau titiknya
/// kurang dari dua diabaikan. Berkas rusak/kosong menghasilkan peta kosong
/// (aman, tidak melempar).
Map<String, Map<String, List<LatLng>>> parseCorridorRoutesGeoJson(String raw) {
  // Buang BOM bila ada (mis. berkas yang ditulis editor Windows).
  final text = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
  if (text.trim().isEmpty) return const {};

  Object? decoded;
  try {
    decoded = json.decode(text);
  } on FormatException {
    return const {};
  }

  if (decoded is! Map<String, dynamic>) return const {};
  if (decoded['type'] != 'FeatureCollection') return const {};
  final features = decoded['features'];
  if (features is! List) return const {};

  final corridors = <String, Map<String, List<LatLng>>>{};
  for (final feature in features) {
    if (feature is! Map<String, dynamic>) continue;

    final geometry = feature['geometry'];
    if (geometry is! Map<String, dynamic>) continue;
    if (geometry['type'] != 'LineString') continue;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) continue;

    final properties = feature['properties'];
    if (properties is! Map<String, dynamic>) continue;
    final corridor = properties['corridor'];
    final direction = properties['direction'];
    if (corridor is! String || corridor.trim().isEmpty) continue;
    if (direction is! String || direction.trim().isEmpty) continue;

    final points = <LatLng>[];
    var readable = true;
    for (final c in coordinates) {
      if (c is! List || c.length < 2 || c[0] is! num || c[1] is! num) {
        readable = false;
        break;
      }
      // GeoJSON: [lng, lat] -> LatLng(lat, lng).
      points.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
    }
    if (!readable || points.length < 2) continue;

    corridors
        .putIfAbsent(corridor.trim().toUpperCase(), () => <String, List<LatLng>>{})
        [direction.trim().toLowerCase()] = points;
  }
  return corridors;
}

/// Mengembalikan isi berkas [asset], atau string kosong bila tidak bisa dibaca.
Future<String> _loadAssetOrEmpty(String asset) async {
  try {
    return await rootBundle.loadString(asset);
  } catch (_) {
    return '';
  }
}

/// Memuat geometri koridor yang digambar manual dari berkas GeoJSON di
/// [corridorRouteGeoJsonDir]. Semua berkas digabung; koridor/arah yang sama
/// memakai berkas terakhir.
Future<CorridorRouteDataset> loadManualCorridorRouteDataset() async {
  final assets = await _corridorRouteGeoJsonAssets();
  final corridors = <String, Map<String, List<LatLng>>>{};

  for (final asset in assets) {
    final raw = await _loadAssetOrEmpty(asset);
    if (raw.trim().isEmpty) continue;
    parseCorridorRoutesGeoJson(raw).forEach((kode, directions) {
      corridors
          .putIfAbsent(kode, () => <String, List<LatLng>>{})
          .addAll(directions);
    });
  }
  return CorridorRouteDataset(corridors);
}

/// Daftar berkas GeoJSON koridor di [corridorRouteGeoJsonDir] dari manifest aset.
Future<List<String>> _corridorRouteGeoJsonAssets() async {
  String manifest;
  try {
    manifest = await rootBundle.loadString('AssetManifest.json');
  } catch (_) {
    return const [];
  }

  Object? decoded;
  try {
    decoded = json.decode(manifest);
  } on FormatException {
    return const [];
  }
  if (decoded is! Map<String, dynamic>) return const [];

  final assets = decoded.keys
      .where((key) =>
          key.startsWith(corridorRouteGeoJsonDir) && key.endsWith('.geojson'))
      .toList()
    ..sort();
  return assets;
}

/// Memuat geometri jalur koridor hasil bangkitan otomatis dari
/// `assets/corridor_routes.json` (lihat `scripts/generate_corridor_routes.ps1`).
Future<CorridorRouteDataset> loadCorridorRouteDataset() async {
  final raw = await rootBundle.loadString('assets/corridor_routes.json');
  final map = json.decode(raw) as Map<String, dynamic>;
  final corridors = <String, Map<String, List<LatLng>>>{};

  map.forEach((kode, value) {
    final directions = <String, List<LatLng>>{};
    (value as Map<String, dynamic>).forEach((dirKey, points) {
      directions[dirKey] = [
        for (final p in (points as List))
          LatLng(
            ((p as List)[0] as num).toDouble(),
            (p[1] as num).toDouble(),
          ),
      ];
    });
    corridors[kode.trim().toUpperCase()] = directions;
  });

  return CorridorRouteDataset(corridors);
}
