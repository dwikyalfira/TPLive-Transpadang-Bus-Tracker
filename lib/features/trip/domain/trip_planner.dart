import 'package:latlong2/latlong.dart';

import '../../../core/config.dart';
import '../../tracking/data/halte_data.dart';
import '../../tracking/domain/geo_utils.dart' as geo;

/// Satu segmen perjalanan memakai satu koridor (satu arah).
class TripLeg {
  final String corridor;
  final String arahKey; // 'pergi' | 'pulang'
  final String directionLabel;
  final Halte board;
  final Halte alight;
  final int boardIndex;
  final int alightIndex;
  final int stopCount;
  final double rideKm;
  final int rideMinutes;

  const TripLeg({
    required this.corridor,
    required this.arahKey,
    required this.directionLabel,
    required this.board,
    required this.alight,
    required this.boardIndex,
    required this.alightIndex,
    required this.stopCount,
    required this.rideKm,
    required this.rideMinutes,
  });

  @override
  bool operator ==(Object other) =>
      other is TripLeg &&
      other.corridor == corridor &&
      other.arahKey == arahKey &&
      other.boardIndex == boardIndex &&
      other.alightIndex == alightIndex;

  @override
  int get hashCode => Object.hash(corridor, arahKey, boardIndex, alightIndex);
}

/// Satu pilihan rute (langsung atau 1 transit).
class TripOption {
  final List<TripLeg> legs;
  final double walkToBoardKm;
  final double walkFromAlightKm;

  /// Jalan kaki saat berpindah bus antar dua halte berbeda nama (km).
  final double transferWalkKm;
  final int walkMinutes;
  final int totalMinutes;

  const TripOption({
    required this.legs,
    required this.walkToBoardKm,
    required this.walkFromAlightKm,
    this.transferWalkKm = 0,
    required this.walkMinutes,
    required this.totalMinutes,
  });

  int get transferCount => legs.length - 1;

  Halte get board => legs.first.board;

  Halte get alight => legs.last.alight;

  double get rideKm =>
      legs.fold<double>(0, (sum, leg) => sum + leg.rideKm);

  /// Total seluruh jarak jalan kaki (menuju halte, saat pindah, dan menuju
  /// tujuan akhir).
  double get totalWalkKm => walkToBoardKm + transferWalkKm + walkFromAlightKm;

  double get totalKm => rideKm + totalWalkKm;

  /// Kode koridor yang dipakai, mis. "K3" atau "K1 → K3".
  String get corridorChain =>
      legs.map((leg) => leg.corridor).toSet().join(' → ');
}

/// Hasil perhitungan rute menuju satu destinasi.
class TripPlan {
  final LatLng origin;
  final LatLng destination;
  final String destinationLabel;
  final List<TripOption> options;

  const TripPlan({
    required this.origin,
    required this.destination,
    required this.destinationLabel,
    required this.options,
  });

  bool get hasOptions => options.isNotEmpty;
}

/// Perencana perjalanan TransPadang: langsung + maksimal 1 kali transit.
class TripPlanner {
  TripPlanner._();

  /// Menghitung [maxOptions] rute terbaik dari [origin] ke [destination].
  static TripPlan plan(
    HalteDataset dataset,
    LatLng origin,
    LatLng destination, {
    required String destinationLabel,
    String? originName,
    String? destinationName,
    int maxOptions = 6,
  }) {
    final options = <TripOption>[];

    for (final stops in dataset.corridors.values) {
      stops.arah.forEach((dirKey, dir) {
        _addDirect(
          options,
          stops.kode,
          dirKey,
          dir,
          origin,
          destination,
          originName,
          destinationName,
        );
      });
    }
    _addTransits(
      dataset,
      origin,
      destination,
      options,
      originName: originName,
      destinationName: destinationName,
    );

    // Buang opsi yang total jalannya melebihi batas wajar (tidak masuk akal).
    options.removeWhere((o) => o.totalWalkKm > AppConfig.maxWalkKm);

    // Bila sudah ada rute langsung, singkirkan opsi transit yang tidak lebih
    // cepat dari rute langsung terbaik — memindahkan koridor jadi sia-sia.
    final bestDirectMinutes = options
        .where((o) => o.transferCount == 0)
        .fold<int?>(null, (best, o) =>
            best == null || o.totalMinutes < best ? o.totalMinutes : best);
    if (bestDirectMinutes != null) {
      options.removeWhere(
          (o) => o.transferCount > 0 && o.totalMinutes >= bestDirectMinutes);
    }

    options.sort((a, b) {
      final byTime = a.totalMinutes.compareTo(b.totalMinutes);
      if (byTime != 0) return byTime;
      return a.transferCount.compareTo(b.transferCount);
    });

    final seen = <String>{};
    final unique = <TripOption>[];
    for (final option in options) {
      final key = option.legs
          .map((l) => '${l.corridor}${l.boardIndex}>${l.alightIndex}')
          .join('|');
      if (seen.add(key)) unique.add(option);
      if (unique.length >= maxOptions) break;
    }

    return TripPlan(
      origin: origin,
      destination: destination,
      destinationLabel: destinationLabel,
      options: unique,
    );
  }

  static void _addDirect(
    List<TripOption> out,
    String corridor,
    String dirKey,
    CorridorDirection dir,
    LatLng origin,
    LatLng destination,
    String? originName,
    String? destinationName,
  ) {
    if (dir.halte.length < 2) return;
    final bi = _resolveIndex(dir.halte, origin, originName);
    final ai = _resolveIndex(dir.halte, destination, destinationName);
    if (bi >= ai) return;
    out.add(_buildOption(
      [
        _buildLeg(corridor, dirKey, dir, bi, ai),
      ],
      origin,
      destination,
      originName,
      destinationName,
    ));
  }

  static void _addTransits(
    HalteDataset dataset,
    LatLng origin,
    LatLng destination,
    List<TripOption> out, {
    String? originName,
    String? destinationName,
  }) {
    final corridors = dataset.corridors.values.toList(growable: false);
    for (final first in corridors) {
      for (final second in corridors) {
        if (identical(first, second) || first.kode == second.kode) continue;
        first.arah.forEach((firstKey, firstDir) {
          second.arah.forEach((secondKey, secondDir) {
            for (final name in _sharedNames(firstDir, secondDir)) {
              final aIdx = _indexOf(firstDir.halte, name);
              final bIdx = _indexOf(secondDir.halte, name);
              if (aIdx <= 0 || bIdx < 0 || bIdx >= secondDir.halte.length - 1) {
                continue;
              }
              final bi = _resolveIndexInRange(
                  firstDir.halte, origin, 0, aIdx - 1, originName);
              final ai = _resolveIndexInRange(secondDir.halte, destination,
                  bIdx + 1, secondDir.halte.length - 1, destinationName);
              if (bi == null || ai == null) continue;
              if (bi >= aIdx || ai <= bIdx) continue;

              out.add(_buildOption(
                [
                  _buildLeg(first.kode, firstKey, firstDir, bi, aIdx),
                  _buildLeg(second.kode, secondKey, secondDir, bIdx, ai),
                ],
                origin,
                destination,
                originName,
                destinationName,
              ));
            }

            _addWalkTransfers(
              out,
              first.kode,
              firstKey,
              firstDir,
              second.kode,
              secondKey,
              secondDir,
              origin,
              destination,
              originName,
              destinationName,
            );
          });
        });
      }
    }
  }

  /// Pindah bus dengan jalan kaki singkat antar dua halte berbeda nama yang
  /// berdekatan (mis. turun di halte koridor A, jalan, lalu naik koridor B).
  static void _addWalkTransfers(
    List<TripOption> out,
    String firstKode,
    String firstKey,
    CorridorDirection firstDir,
    String secondKode,
    String secondKey,
    CorridorDirection secondDir,
    LatLng origin,
    LatLng destination,
    String? originName,
    String? destinationName,
  ) {
    final aHalte = firstDir.halte;
    final bHalte = secondDir.halte;
    for (var aIdx = 1; aIdx < aHalte.length; aIdx++) {
      final a = aHalte[aIdx];
      for (var bIdx = 0; bIdx < bHalte.length - 1; bIdx++) {
        final b = bHalte[bIdx];
        if (_sameName(a.nama, b.nama)) continue;
        if (geo.distanceKm(a.pos, b.pos) > AppConfig.transferWalkKm) continue;
        final bi =
            _resolveIndexInRange(aHalte, origin, 0, aIdx - 1, originName);
        final ai = _resolveIndexInRange(
            bHalte, destination, bIdx + 1, bHalte.length - 1, destinationName);
        if (bi == null || ai == null) continue;
        if (bi >= aIdx || ai <= bIdx) continue;

        out.add(_buildOption(
          [
            _buildLeg(firstKode, firstKey, firstDir, bi, aIdx),
            _buildLeg(secondKode, secondKey, secondDir, bIdx, ai),
          ],
          origin,
          destination,
          originName,
          destinationName,
        ));
      }
    }
  }

  static TripLeg _buildLeg(
    String corridor,
    String dirKey,
    CorridorDirection dir,
    int boardIndex,
    int alightIndex,
  ) {
    var rideKm = 0.0;
    for (var i = boardIndex; i < alightIndex; i++) {
      rideKm += geo.distanceKm(dir.halte[i].pos, dir.halte[i + 1].pos);
    }
    final minutes = (rideKm / AppConfig.defaultSpeedKmh * 60).round();
    return TripLeg(
      corridor: corridor,
      arahKey: dirKey,
      directionLabel: dir.label,
      board: dir.halte[boardIndex],
      alight: dir.halte[alightIndex],
      boardIndex: boardIndex,
      alightIndex: alightIndex,
      stopCount: alightIndex - boardIndex,
      rideKm: rideKm,
      rideMinutes: minutes,
    );
  }

  static TripOption _buildOption(
    List<TripLeg> legs,
    LatLng origin,
    LatLng destination,
    String? originName,
    String? destinationName,
  ) {
    final board = legs.first.board;
    final alight = legs.last.alight;
    final walkToBoardKm = _walkKm(origin, board, originName);
    final walkFromAlightKm = _walkKm(destination, alight, destinationName);
    final transferWalkKm = _transferWalkKm(legs);
    final walkMinutes = ((walkToBoardKm + transferWalkKm + walkFromAlightKm) /
            AppConfig.walkSpeedKmh *
            60)
        .round();
    final rideMinutes =
        legs.fold<int>(0, (sum, leg) => sum + leg.rideMinutes);
    final transferMinutes = (legs.length - 1) * AppConfig.transferPenaltyMinutes;
    return TripOption(
      legs: legs,
      walkToBoardKm: walkToBoardKm,
      walkFromAlightKm: walkFromAlightKm,
      transferWalkKm: transferWalkKm,
      walkMinutes: walkMinutes,
      totalMinutes: walkMinutes + rideMinutes + transferMinutes,
    );
  }

  /// Jalan kaki saat berpindah bus: jarak antar halte turun rute dan halte naik
  /// rute berikutnya. Halte dengan nama sama dianggap satu halte (jarak = 0),
  /// meski koordinatnya berbeda antar koridor.
  static double _transferWalkKm(List<TripLeg> legs) {
    var sum = 0.0;
    for (var i = 0; i + 1 < legs.length; i++) {
      final a = legs[i].alight;
      final b = legs[i + 1].board;
      if (!_sameName(a.nama, b.nama)) {
        sum += geo.distanceKm(a.pos, b.pos);
      }
    }
    return sum;
  }

  /// Jarak jalan dari [point] ke halte [halte]. Bila titik ujungnya memang
  /// halte itu sendiri (dicocokkan lewat nama, bukan koordinat), jarak = 0;
  /// ini menghindari penalti jalan akibat koordinat halte bernama sama yang
  /// berbeda antar koridor.
  static double _walkKm(LatLng point, Halte halte, String? endpointName) {
    if (endpointName != null && _sameName(halte.nama, endpointName)) return 0.0;
    return geo.distanceKm(point, halte.pos);
  }

  /// Indeks halte untuk [point]: utamakan kecocokan nama [name] bila ada,
  /// jika tidak pakai halte terdekat.
  static int _resolveIndex(List<Halte> halte, LatLng point, String? name) {
    if (name != null) {
      final idx = _indexOf(halte, name);
      if (idx >= 0) return idx;
    }
    return _nearestIndex(halte, point);
  }

  /// Seperti [_resolveIndex] tetapi dibatasi rentang indeks [start]..[endInclusive].
  static int? _resolveIndexInRange(
    List<Halte> halte,
    LatLng point,
    int start,
    int endInclusive,
    String? name,
  ) {
    if (name != null) {
      final idx = _indexOf(halte, name);
      if (idx >= start && idx <= endInclusive) return idx;
    }
    return _nearestIndexInRange(halte, point, start, endInclusive);
  }

  static bool _sameName(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  static int _nearestIndex(List<Halte> halte, LatLng point) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < halte.length; i++) {
      final d = geo.distanceKm(point, halte[i].pos);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  static int? _nearestIndexInRange(
    List<Halte> halte,
    LatLng point,
    int start,
    int endInclusive,
  ) {
    if (start < 0 || endInclusive >= halte.length || start > endInclusive) {
      return null;
    }
    var best = start;
    var bestD = double.infinity;
    for (var i = start; i <= endInclusive; i++) {
      final d = geo.distanceKm(point, halte[i].pos);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  static int _indexOf(List<Halte> halte, String name) {
    for (var i = 0; i < halte.length; i++) {
      if (halte[i].nama.toLowerCase() == name.toLowerCase()) return i;
    }
    return -1;
  }

  static Set<String> _names(List<Halte> halte) =>
      {for (final h in halte) h.nama.toLowerCase()};

  static List<String> _sharedNames(
    CorridorDirection a,
    CorridorDirection b,
  ) {
    final bNames = _names(b.halte);
    final shared = <String>[];
    for (final h in a.halte) {
      if (bNames.contains(h.nama.toLowerCase())) shared.add(h.nama);
    }
    return shared;
  }
}
