import 'package:latlong2/latlong.dart';

import '../data/bus_model.dart';
import 'geo_utils.dart' as geo;

/// Bus beserta jarak dan estimasi waktu ke pengguna.
class BusWithDistance {
  final Bus bus;
  final double distanceKm;
  final int? etaMinutes;

  /// Nama terminus tujuan pada arah yang sedang ditempuh.
  final String? destinationLabel;

  /// Arah gerak yang dipakai untuk menentukan arah (derajat) bila ada.
  final double? resolvedHeading;

  const BusWithDistance({
    required this.bus,
    required this.distanceKm,
    required this.etaMinutes,
    this.destinationLabel,
    this.resolvedHeading,
  });

  factory BusWithDistance.compute(
    Bus bus,
    LatLng userLocation, {
    String? destinationLabel,
    double? resolvedHeading,
  }) {
    final km = geo.distanceKm(userLocation, bus.position);
    return BusWithDistance(
      bus: bus,
      distanceKm: km,
      etaMinutes: geo.estimateEtaMinutes(km, bus.speedKmh),
      destinationLabel: destinationLabel,
      resolvedHeading: resolvedHeading,
    );
  }
}
