import 'package:latlong2/latlong.dart';

import '../data/corridor_route.dart';
import '../data/halte_data.dart';

/// Jalur satu arah koridor di peta (data murni, tanpa widget).
class CorridorPath {
  final String corridor;
  final String directionKey;
  final List<LatLng> points;

  const CorridorPath({
    required this.corridor,
    required this.directionKey,
    required this.points,
  });
}

/// Menyusun jalur koridor dari [dataset] untuk digambar di peta.
///
/// Satu [CorridorPath] per arah (`pergi`/`pulang`) yang memiliki minimal dua
/// titik. Bila [routeGeometry] tersedia untuk sebuah arah, geometri mengikuti
/// jalan itu dipakai; jika tidak, jalur jatuh ke garis lurus antar-halte. Arah
/// dengan kurang dari dua titik dilewati karena tidak bisa membentuk garis.
/// Bila [filterCorridor] diisi, hanya koridor itu yang disertakan; perbandingan
/// koridor mengabaikan besar-kecil huruf.
List<CorridorPath> buildCorridorPaths(
  HalteDataset dataset, {
  String? filterCorridor,
  CorridorRouteDataset? routeGeometry,
}) {
  final target = filterCorridor?.trim().toUpperCase();
  final result = <CorridorPath>[];
  dataset.corridors.forEach((kode, stops) {
    if (target != null && target.isNotEmpty && kode.toUpperCase() != target) {
      return;
    }
    stops.arah.forEach((dirKey, direction) {
      final points = routeGeometry?.points(kode, dirKey) ??
          [for (final halte in direction.halte) halte.pos];
      if (points.length < 2) return;
      result.add(CorridorPath(
        corridor: kode,
        directionKey: dirKey,
        points: points,
      ));
    });
  });
  return result;
}
