import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

import '../../../core/config.dart';

/// Satu hasil pencarian tempat dari layanan geocoding.
class GeocodingResult {
  /// Nama pendek (mis. "Masjid Raya Sumatera Barat").
  final String name;

  /// Nama lengkap dengan alamat (untuk subtitle).
  final String displayName;

  final LatLng pos;

  const GeocodingResult({
    required this.name,
    required this.displayName,
    required this.pos,
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    final display = (json['display_name'] ?? '').toString();
    final rawName = (json['name'] ?? '').toString().trim();
    final name = rawName.isNotEmpty
        ? rawName
        : display.split(',').first.trim();
    return GeocodingResult(
      name: name.isEmpty ? display : name,
      displayName: display,
      pos: LatLng(
        double.tryParse('${json['lat']}') ?? 0,
        double.tryParse('${json['lon']}') ?? 0,
      ),
    );
  }

  /// Memetakan satu fitur GeoJSON dari Mapbox Search Box API.
  factory GeocodingResult.fromMapboxJson(Map<String, dynamic> feature) {
    final geometry = feature['geometry'];
    final rawProps = feature['properties'];
    final props =
        rawProps is Map<String, dynamic> ? rawProps : const <String, dynamic>{};

    var lon = 0.0;
    var lat = 0.0;
    final coordinates =
        geometry is Map<String, dynamic> ? geometry['coordinates'] : null;
    if (coordinates is List && coordinates.length >= 2) {
      lon = (coordinates[0] as num?)?.toDouble() ?? 0;
      lat = (coordinates[1] as num?)?.toDouble() ?? 0;
    }

    final rawName = (props['name'] ?? '').toString().trim();
    final fullAddress = (props['full_address'] ?? '').toString().trim();
    final placeFormatted = (props['place_formatted'] ?? '').toString().trim();
    final display = fullAddress.isNotEmpty
        ? fullAddress
        : (placeFormatted.isNotEmpty ? placeFormatted : rawName);

    return GeocodingResult(
      name: rawName.isEmpty ? display : rawName,
      displayName: display,
      pos: LatLng(lat, lon),
    );
  }
}

/// Kesalahan geocoding dengan pesan ramah pengguna.
class GeocodingException implements Exception {
  final String message;

  const GeocodingException(this.message);

  @override
  String toString() => message;
}

/// Klien pencarian tempat berbasis Nominatim (OpenStreetMap).
///
/// Mengikuti kebijakan penggunaan Nominatim: satu permintaan pada satu waktu,
/// User-Agent jelas, tanpa pemanggilan berlebihan.
class GeocodingService {
  final HttpClient _client;

  GeocodingService({HttpClient? client}) : _client = client ?? HttpClient();

  /// Mencari tempat berdasarkan teks [query] di sekitar Padang.
  Future<List<GeocodingResult>> search(
    String query, {
    int limit = 6,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final uri = Uri.https(AppConfig.geocoderHost, '/search', {
      'q': q,
      'format': 'jsonv2',
      'limit': '$limit',
      'addressdetails': '1',
      'countrycodes': 'id',
      'accept-language': AppConfig.geocoderLanguage,
      'viewbox': AppConfig.padangViewbox,
      'bounded': '1',
      'dedupe': '1',
    });

    try {
      final request = await _client.getUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.userAgentHeader, AppConfig.geocoderUserAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join().timeout(timeout);

      if (response.statusCode != HttpStatus.ok) {
        throw GeocodingException(
          'Pencarian gagal (HTTP ${response.statusCode}). Coba lagi nanti.',
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(GeocodingResult.fromJson)
          .where((r) => r.pos.latitude != 0 || r.pos.longitude != 0)
          .toList(growable: false);
    } on TimeoutException {
      throw const GeocodingException(
        'Pencarian memakan waktu terlalu lama. Periksa koneksi internet.',
      );
    } on SocketException {
      throw const GeocodingException('Tidak ada koneksi internet.');
    } on FormatException {
      throw const GeocodingException('Respons pencarian tidak valid.');
    }
  }

  void close() => _client.close(force: true);
}
