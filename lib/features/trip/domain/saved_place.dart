import 'package:latlong2/latlong.dart';

import 'trip_endpoint.dart';

/// Jenis tempat tersimpan: halte TransPadang atau tempat hasil pencarian (POI).
enum SavedPlaceKind { halte, place }

/// Tempat yang disimpan pengguna (favorit atau riwayat tujuan).
///
/// Bentuknya adalah versi serializable dari [TripEndpoint] — GPS sengaja tidak
/// dapat disimpan karena posisinya selalu berubah.
class SavedPlace {
  final SavedPlaceKind kind;
  final String label;
  final double lat;
  final double lng;

  /// Daftar koridor yang melewati halte ini (khusus [SavedPlaceKind.halte]).
  final String? corridors;

  const SavedPlace({
    required this.kind,
    required this.label,
    required this.lat,
    required this.lng,
    this.corridors,
  });

  LatLng get position => LatLng(lat, lng);

  /// Identitas stabil untuk deduplikasi & pencarian favorit.
  String get id =>
      '${kind.name}:${label.trim().toLowerCase()}:'
      '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';

  TripEndpoint toEndpoint() => TripEndpoint(
        kind: kind == SavedPlaceKind.halte
            ? EndpointKind.halte
            : EndpointKind.place,
        label: label,
        position: position,
        corridors: corridors,
      );

  /// Mengembalikan `null` bila [endpoint] adalah lokasi GPS (tidak disimpan).
  static SavedPlace? fromEndpoint(TripEndpoint endpoint) {
    final pos = endpoint.position;
    if (endpoint.isGps || pos == null) return null;
    final isHalte = endpoint.kind == EndpointKind.halte;
    return SavedPlace(
      kind: isHalte ? SavedPlaceKind.halte : SavedPlaceKind.place,
      label: endpoint.label,
      lat: pos.latitude,
      lng: pos.longitude,
      corridors: isHalte ? endpoint.corridors : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'label': label,
        'lat': lat,
        'lng': lng,
        if (corridors != null) 'corridors': corridors,
      };

  factory SavedPlace.fromJson(Map<String, dynamic> json) {
    final kindName = (json['kind'] ?? '').toString();
    return SavedPlace(
      kind: kindName == SavedPlaceKind.halte.name
          ? SavedPlaceKind.halte
          : SavedPlaceKind.place,
      label: (json['label'] ?? '').toString(),
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      corridors: json['corridors']?.toString(),
    );
  }
}
