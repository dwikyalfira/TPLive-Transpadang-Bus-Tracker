import 'package:latlong2/latlong.dart';

import '../data/bus_model.dart';
import '../data/halte_data.dart';
import 'geo_utils.dart' as geo;

/// Status satu halte relatif terhadap posisi bus.
enum HalteMark { passed, current, next, upcoming }

/// Penahan perpindahan "halte berikutnya" saat bus berhenti di dekat batas.
///
/// Menyimpan indeks terakhir per bus; calon baru hanya diterapkan setelah
/// muncul [requiredHits] kali berturut-turut. Tanpa ini, satu meter goyangan
/// GPS di dekat batas dua halte membuat penanda dan teks "halte berikutnya"
/// berkedip.
class HalteHysteresis {
  /// Jumlah pembacaan berturut-turut sebelum perpindahan diterapkan.
  final int requiredHits;

  final Map<String, int> _last = <String, int>{};
  final Map<String, int> _pending = <String, int>{};

  HalteHysteresis({this.requiredHits = 2});

  /// Indeks "halte berikutnya" yang dipakai untuk pembacaan [candidate].
  int resolve(String busKey, int candidate) {
    final previous = _last[busKey];
    if (previous == null) {
      _last[busKey] = candidate;
      _pending[busKey] = 0;
      return candidate;
    }
    if (candidate == previous) {
      _pending[busKey] = 0;
      return previous;
    }
    final hits = (_pending[busKey] ?? 0) + 1;
    if (hits >= requiredHits) {
      _last[busKey] = candidate;
      _pending[busKey] = 0;
      return candidate;
    }
    _pending[busKey] = hits;
    return previous;
  }

  /// Lupakan riwayat satu bus (mis. setelah bus hilang dari data live).
  void forget(String busKey) {
    _last.remove(busKey);
    _pending.remove(busKey);
  }

  /// Bersihkan seluruh riwayat (dipakai pengujian).
  void reset() {
    _last.clear();
    _pending.clear();
  }
}

/// Satu baris pada timeline halte.
class HalteStep {
  final Halte halte;
  final HalteMark mark;

  /// Jarak garis lurus dari bus ke halte ini (km).
  final double distanceKm;

  const HalteStep({
    required this.halte,
    required this.mark,
    required this.distanceKm,
  });
}

/// Hasil pelacakan posisi bus sepanjang urutan halte satu arah.
class HalteProgress {
  final CorridorDirection direction;
  final String arahKey; // 'pergi' | 'pulang'
  final List<HalteStep> steps;
  final int nextIndex;
  final int? currentIndex;

  /// Arah gerak/heading yang dipakai untuk menentukan arah (derajat) bila ada.
  final double? resolvedHeading;

  /// Nama terminus tujuan dari route resmi server untuk arah yang ditempuh
  /// (mis. "RTH Imam Bonjol Ruas Hasanuddin" atau "Pusat Pemerintahan Balai
  /// Kota Padang"), bila route berhasil diparse.
  final String? destination;

  /// Nama terminus asal dari route resmi server untuk arah yang ditempuh.
  final String? origin;

  const HalteProgress({
    required this.direction,
    required this.arahKey,
    required this.steps,
    required this.nextIndex,
    required this.currentIndex,
    this.resolvedHeading,
    this.destination,
    this.origin,
  });

  /// Nama terminus tujuan pada arah yang sedang ditempuh (tanpa prefix).
  ///
  /// Diutamakan endpoint resmi route; fallback ke nama halte terakhir.
  String get destinationLabel => destination ?? direction.halte.last.nama;

  /// Nama terminus asal pada arah yang sedang ditempuh (tanpa prefix).
  String get originLabel => origin ?? direction.halte.first.nama;

  HalteStep? get nextStep =>
      (nextIndex >= 0 && nextIndex < steps.length) ? steps[nextIndex] : null;

  HalteStep? get currentStep => currentIndex == null
      ? null
      : (currentIndex! >= 0 && currentIndex! < steps.length
          ? steps[currentIndex!]
          : null);
}

class HalteTracker {
  HalteTracker._();

  /// Instance bersama untuk [trackStable]: menahan penanda halte agar tidak
  /// berpindah-pindah saat bus berhenti tepat di batas dua halte.
  static final HalteHysteresis _sharedHysteresis = HalteHysteresis();

  /// Seperti [track], tetapi memakai histeresis bersama.
  ///
  /// Dipakai lapisan UI (kartu bus, peta, timeline). Perpindahan "halte
  /// berikutnya" baru diterapkan setelah calon baru muncul dua kali berturut,
  /// sehingga penanda tidak berkedip saat GPS/kecepatan bus berisik di dekat
  /// ambang. Pengujian sebaiknya memakai [track] tanpa histeresis.
  static HalteProgress? trackStable(
    Bus bus,
    HalteDataset dataset, {
    double? estimatedHeading,
  }) =>
      track(bus, dataset,
          estimatedHeading: estimatedHeading, hysteresis: _sharedHysteresis);

  /// Koridor yang arah `pergi`-nya menuju endpoint PERTAMA pada string route
  /// (mis. "RTH Imam Bonjol - Mega Permai Lubuk Buaya" → pergi ke RTH Imam
  /// Bonjol). Untuk koridor lain, `pergi` menuju endpoint KEDUA. Pemetaan ini
  /// tetap karena string route server statis per koridor.
  static const Set<String> _pergiToFirstEndpoint = {'K1'};

  /// Menghasilkan posisi bus relatif terhadap timeline halte koridornya.
  ///
  /// [estimatedHeading] (dari riwayat gerak) dipakai lebih dulu; bila `null`
  /// dipakai `Bus.heading` dari server. Mengembalikan `null` bila koridor bus
  /// tidak ada di dataset.
  static HalteProgress? track(
    Bus bus,
    HalteDataset dataset, {
    double? estimatedHeading,
    HalteHysteresis? hysteresis,
  }) {
    final stops = dataset.forCorridor(bus.corridor);
    if (stops == null) return null;

    final heading = _valid(estimatedHeading) ?? _valid(bus.heading);
    final dir = _pickDirection(bus, stops, heading);
    if (dir == null || dir.halte.length < 2) return null;

    final key = identical(dir, stops.pulang) ? 'pulang' : 'pergi';
    return _build(bus, dir, key, heading, hysteresis);
  }

  static double? _valid(double? v) =>
      (v != null && v.isFinite && v >= 0 && v < 360) ? v : null;

  static CorridorDirection? _pickDirection(
    Bus bus,
    CorridorStops stops,
    double? heading,
  ) {
    final pergi = stops.pergi;
    final pulang = stops.pulang;
    if (pergi == null) return pulang;
    if (pulang == null) return pergi;
    if (pergi.halte.isEmpty) return pulang;
    if (pulang.halte.isEmpty) return pergi;

    final pos = bus.position;
    final iPergi = _nearestIndex(pergi.halte, pos);
    final iPulang = _nearestIndex(pulang.halte, pos);

    if (heading != null) {
      // Bandingkan heading dengan arah segmen LOKAL di halte terdekat.
      final localPergi = _localBearing(pergi, iPergi);
      final localPulang = _localBearing(pulang, iPulang);
      final dPergi = geo.angularDifference(heading, localPergi);
      final dPulang = geo.angularDifference(heading, localPulang);
      if (dPergi != dPulang) return dPergi < dPulang ? pergi : pulang;
    }

    // Fallback: pilih arah yang haltenya paling dekat.
    final dPergi = geo.distanceKm(pos, pergi.halte[iPergi].pos);
    final dPulang = geo.distanceKm(pos, pulang.halte[iPulang].pos);
    return dPergi <= dPulang ? pergi : pulang;
  }

  static int _nearestIndex(List<Halte> hs, LatLng p) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < hs.length; i++) {
      final d = geo.distanceKm(p, hs[i].pos);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  /// Arah segmen lokal di sekitar index [idx] (diratakan prev->next supaya
  /// tahan terhadap halte yang berdekatan/berisik).
  static double _localBearing(CorridorDirection dir, int idx) {
    final hs = dir.halte;
    if (hs.length < 2) return 0;
    if (idx <= 0) return geo.bearingDegrees(hs[0].pos, hs[1].pos);
    if (idx >= hs.length - 1) {
      return geo.bearingDegrees(hs[hs.length - 2].pos, hs[hs.length - 1].pos);
    }
    return geo.bearingDegrees(hs[idx - 1].pos, hs[idx + 1].pos);
  }

  static HalteProgress _build(
    Bus bus,
    CorridorDirection dir,
    String key,
    double? heading,
    HalteHysteresis? hysteresis,
  ) {
    final points = dir.halte;
    final cum = List<double>.filled(points.length, 0);
    for (var i = 1; i < points.length; i++) {
      cum[i] = cum[i - 1] + geo.distanceKm(points[i - 1].pos, points[i].pos);
    }

    final pos = bus.position;
    final near = _nearestIndex(points, pos);

    var progress = cum[near];
    var bestPerp = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final (perp, t) =
          geo.projectOnSegment(pos, points[i].pos, points[i + 1].pos);
      if (perp < bestPerp) {
        bestPerp = perp;
        progress = cum[i] + t * (cum[i + 1] - cum[i]);
      }
    }

    const eps = 0.03; // 30 m
    int currentIndex;
    int nextIndex;
    if (progress < cum[near] - eps) {
      currentIndex = near - 1;
      nextIndex = near;
    } else {
      currentIndex = near;
      nextIndex = near + 1;
    }
    currentIndex = currentIndex.clamp(-1, points.length - 1);
    nextIndex = nextIndex.clamp(0, points.length - 1);
    if (currentIndex >= nextIndex) currentIndex = nextIndex - 1;

    // Histeresis: tahan "halte berikutnya" di nilai lama sampai calon baru
    // bertahan beberapa pembacaan, supaya penanda tidak bolak-balik saat bus
    // berhenti tepat di ambang dua halte.
    if (hysteresis != null) {
      final held = hysteresis.resolve('${bus.corridor}|${bus.number}', nextIndex);
      if (held != nextIndex) {
        nextIndex = held.clamp(0, points.length - 1);
        currentIndex = nextIndex - 1;
        if (currentIndex < -1) currentIndex = -1;
      }
    }

    final steps = <HalteStep>[];
    for (var i = 0; i < points.length; i++) {
      HalteMark mark;
      if (i == nextIndex) {
        mark = HalteMark.next;
      } else if (i == currentIndex) {
        mark = HalteMark.current;
      } else if (i < nextIndex) {
        mark = HalteMark.passed;
      } else {
        mark = HalteMark.upcoming;
      }
      steps.add(HalteStep(
        halte: points[i],
        mark: mark,
        distanceKm: geo.distanceKm(pos, points[i].pos),
      ));
    }

    return HalteProgress(
      direction: dir,
      arahKey: key,
      steps: steps,
      nextIndex: nextIndex,
      currentIndex: currentIndex >= 0 ? currentIndex : null,
      resolvedHeading: heading,
      destination: _routeTerminus(bus, key),
      origin: _routeOrigin(bus, key),
    );
  }

  /// Memecah string route server "A - B" menjadi (A, B).
  static (String, String)? _splitRoute(String route) {
    final m = RegExp(r'\s+[-\u2013]\s+').firstMatch(route);
    if (m == null) return null;
    final a = route.substring(0, m.start).trim();
    final b = route.substring(m.end).trim();
    if (a.isEmpty || b.isEmpty) return null;
    return (a, b);
  }

  /// Nama terminus tujuan sesuai route resmi untuk arah [key].
  ///
  /// Arah `pergi` menuju endpoint PERTAMA route hanya untuk koridor di
  /// [_pergiToFirstEndpoint]; koridor lain `pergi` menuju endpoint KEDUA.
  static String? _routeTerminus(Bus bus, String key) {
    final ends = _splitRoute(bus.route);
    if (ends == null) return null;
    final first =
        _pergiToFirstEndpoint.contains(bus.corridor) == (key == 'pergi');
    return first ? ends.$1 : ends.$2;
  }

  /// Nama terminus asal sesuai route resmi untuk arah [key] (kebalikan
  /// terminus tujuan).
  static String? _routeOrigin(Bus bus, String key) {
    final ends = _splitRoute(bus.route);
    if (ends == null) return null;
    final first =
        _pergiToFirstEndpoint.contains(bus.corridor) == (key == 'pergi');
    return first ? ends.$2 : ends.$1;
  }
}
