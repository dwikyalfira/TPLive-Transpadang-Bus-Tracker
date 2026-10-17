import 'package:latlong2/latlong.dart';

import '../data/bus_model.dart';

/// Penanda satu bus di peta (data murni, tanpa widget).
class BusMapMarker {
  final String number;
  final String corridor;
  final LatLng position;
  final double? heading;

  const BusMapMarker({
    required this.number,
    required this.corridor,
    required this.position,
    this.heading,
  });
}

/// Menyusun penanda bus dari [buses] untuk ditampilkan di peta.
///
/// Bus yang datanya sudah basi (lihat [Bus.isStale]) dibuang. Bila
/// [filterCorridor] diisi, hanya bus pada koridor itu yang disertakan;
/// perbandingan koridor mengabaikan besar-kecil huruf.
List<BusMapMarker> buildBusMapMarkers(
  List<Bus> buses, {
  String? filterCorridor,
  DateTime? nowUtc,
}) {
  final now = nowUtc ?? DateTime.now().toUtc();
  final target = filterCorridor?.trim().toUpperCase();
  final result = <BusMapMarker>[];
  for (final bus in buses) {
    if (bus.isStale(now)) continue;
    if (target != null && target.isNotEmpty &&
        bus.corridor.toUpperCase() != target) {
      continue;
    }
    result.add(BusMapMarker(
      number: bus.number,
      corridor: bus.corridor,
      position: bus.position,
      heading: _validHeading(bus.heading),
    ));
  }
  return result;
}

double? _validHeading(double? value) {
  if (value == null || !value.isFinite || value < 0 || value >= 360) {
    return null;
  }
  return value;
}
