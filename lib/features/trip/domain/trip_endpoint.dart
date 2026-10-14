import 'package:latlong2/latlong.dart';

import '../../tracking/data/halte_data.dart';

/// Jenis titik perjalanan: lokasi GPS, tempat hasil geocoding, atau halte.
enum EndpointKind { gps, place, halte }

/// Titik asal/tujuan perjalanan.
class TripEndpoint {
  final EndpointKind kind;

  /// Label yang ditampilkan (mis. "Lokasi saya", nama tempat, atau nama halte).
  final String label;

  /// Koordinat tetap; `null` untuk [EndpointKind.gps] (diambil dari GPS).
  final LatLng? position;

  /// Daftar koridor yang melewati halte ini (khusus [EndpointKind.halte]).
  final String? corridors;

  const TripEndpoint({
    required this.kind,
    required this.label,
    this.position,
    this.corridors,
  });

  const TripEndpoint.gps() : this(kind: EndpointKind.gps, label: 'Lokasi saya');

  factory TripEndpoint.place({
    required String label,
    required LatLng position,
  }) {
    return TripEndpoint(
      kind: EndpointKind.place,
      label: label,
      position: position,
    );
  }

  factory TripEndpoint.halte(HalteEntry entry) {
    final corridors = entry.corridors.toList()..sort();
    return TripEndpoint(
      kind: EndpointKind.halte,
      label: entry.name,
      position: entry.halte.pos,
      corridors: corridors.join(', '),
    );
  }

  bool get isGps => kind == EndpointKind.gps;
}

/// Satu halte unik (menggabungkan kemunculan di beberapa koridor).
class HalteEntry {
  final Halte halte;
  final Set<String> corridors;

  HalteEntry({required this.halte, required Set<String> corridors})
      : corridors = {...corridors};

  String get name => halte.nama;
}
