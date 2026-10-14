import 'package:latlong2/latlong.dart';

import '../../../core/config.dart';

/// Model satu bus TransPadang dari pesan `allBusLocation`.
///
/// Catatan penting: server mengirim field `latitude` dan `longitude` dalam
/// keadaan TERBALIK. Nilai `longitude` sebenarnya adalah latitude, dan
/// sebaliknya. [Bus.fromJson] sudah menormalkan hal ini.
class Bus {
  final String number;
  final double lat;
  final double lng;
  final String corridor;
  final String route;
  final double? heading; // dari field 'direct'
  final double? speedKmh; // dari field 'speed'
  final DateTime? lastUpdate; // UTC (hasil konversi dari waktu WIB)

  const Bus({
    required this.number,
    required this.lat,
    required this.lng,
    required this.corridor,
    required this.route,
    this.heading,
    this.speedKmh,
    this.lastUpdate,
  });

  LatLng get position => LatLng(lat, lng);

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  /// Parse waktu server (format "yyyy-MM-dd HH:mm:ss") sebagai WIB (UTC+7),
  /// lalu kembalikan sebagai UTC.
  static DateTime? _parseWib(dynamic value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString().replaceFirst(' ', 'T'));
    if (parsed == null) return null;
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
    ).subtract(const Duration(hours: AppConfig.wibOffsetHours));
  }

  factory Bus.fromJson(Map<String, dynamic> json) {
    // Field latitude/longitude TERBALIK di server.
    final lat = _toDouble(json['longitude']) ?? 0;
    final lng = _toDouble(json['latitude']) ?? 0;
    return Bus(
      number: (json['bus'] ?? '').toString(),
      lat: lat,
      lng: lng,
      corridor: (json['corridor'] ?? '').toString(),
      route: (json['route'] ?? '').toString(),
      heading: _toDouble(json['direct']),
      speedKmh: _toDouble(json['speed']),
      lastUpdate: _parseWib(json['last_update']),
    );
  }

  bool isStale(DateTime nowUtc) {
    final updated = lastUpdate;
    if (updated == null) return false;
    return nowUtc.difference(updated) > AppConfig.staleAfter;
  }

  Duration? age(DateTime nowUtc) {
    final updated = lastUpdate;
    if (updated == null) return null;
    return nowUtc.difference(updated);
  }
}
