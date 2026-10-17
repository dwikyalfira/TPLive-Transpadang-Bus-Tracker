import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../data/bus_model.dart';
import 'geo_utils.dart' as geo;

class _Sample {
  final LatLng pos;
  final DateTime time;

  const _Sample(this.pos, this.time);
}

/// Memperkirakan arah gerak bus dari riwayat posisinya.
///
/// Field `direct` dari server kadang "noise" saat bus berbelok/berhenti.
/// Kelas ini menyimpan beberapa sampel posisi terakhir per bus dan menghitung
/// arah gerak aktual (vector sum berbobot jarak). Dipakai sebagai arah utama
/// bila tersedia dan cukup andal; jika tidak, pemanggil dapat fallback ke
/// `Bus.heading`.
class HeadingTracker {
  final Map<String, List<_Sample>> _history = {};

  static const int _maxSamples = 8;
  static const Duration _window = Duration(seconds: 30);
  static const double _minSampleMoveKm = 0.004; // 4 m
  static const double _minTotalMoveKm = 0.04; // 40 m

  static const double _deg = 180 / math.pi;

  /// Memperbarui riwayat untuk [bus] dan mengembalikan perkiraan arah gerak
  /// (derajat, 0 = utara) atau `null` bila belum cukup data.
  double? update(Bus bus, DateTime nowUtc) {
    final key = '${bus.corridor}/${bus.number}';
    final samples = _history.putIfAbsent(key, () => <_Sample>[]);
    final pos = bus.position;

    if (samples.isEmpty) {
      samples.add(_Sample(pos, nowUtc));
    } else {
      final moved = geo.distanceKm(samples.last.pos, pos);
      if (moved > _minSampleMoveKm) {
        samples.add(_Sample(pos, nowUtc));
      } else {
        samples[samples.length - 1] = _Sample(pos, nowUtc);
      }
    }

    samples.removeWhere((s) => nowUtc.difference(s.time) > _window);
    while (samples.length > _maxSamples) {
      samples.removeAt(0);
    }

    if (samples.length < 2) return null;

    var sx = 0.0, sy = 0.0, total = 0.0;
    for (var i = 1; i < samples.length; i++) {
      final a = samples[i - 1].pos;
      final b = samples[i].pos;
      final d = geo.distanceKm(a, b);
      if (d < _minSampleMoveKm) continue;
      final rad = geo.bearingDegrees(a, b) / _deg;
      sx += math.cos(rad) * d;
      sy += math.sin(rad) * d;
      total += d;
    }

    if (total < _minTotalMoveKm) return null;
    final deg = math.atan2(sy, sx) * _deg;
    return (deg + 360) % 360;
  }
}
