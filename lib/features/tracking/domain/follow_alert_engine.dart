import '../../trip/domain/trip_planner.dart';

/// Jenis pemberitahuan kedatangan bus yang sedang diikuti.
enum FollowAlertType {
  /// Bus tinggal 1-2 halte lagi menuju halte naik.
  approachingBoard,

  /// Bus sudah di halte naik — saatnya naik.
  atBoard,

  /// Bus tinggal 1-2 halte lagi menuju halte turun.
  approachingAlight,

  /// Bus sudah di halte turun — saatnya turun.
  atAlight,
}

/// Kandidat pemberitahuan yang laik dikirim pada satu pembaruan posisi bus.
class FollowAlertCandidate {
  final FollowAlertType type;

  /// Sisa jumlah halte (bernilai 1..2 untuk "mendekat", 0 untuk "sudah tiba").
  final int remaining;

  /// Nama halte naik/turun yang menjadi acuan.
  final String halteName;

  const FollowAlertCandidate({
    required this.type,
    required this.remaining,
    required this.halteName,
  });

  /// Kunci sesi agar pemberitahuan hanya dikirim sekali per kejadian.
  String get dedupeKey => '${type.name}:$halteName:$remaining';
}

/// Logika murni (tanpa I/O) penentuan pemberitahuan kedatangan bus.
class FollowAlertEngine {
  FollowAlertEngine._();

  /// Ambang "mendekat": jumlah halte tersisa yang memicu peringatan.
  static const int approachRadius = 2;

  /// Menentukan kandidat pemberitahuan untuk progres [nextIndex]/[currentIndex]
  /// saat ini. [halteNames] adalah nama halte berindeks urutan arah.
  ///
  /// Sisa halte = `halteAcuan - idx` dengan `idx = currentIndex ?? nextIndex`.
  /// Nilai 1..2 memicu "mendekat"; nilai 0 (bus tepat di halte) memicu
  /// "saatnya naik/turun".
  static List<FollowAlertCandidate> evaluate({
    required int nextIndex,
    required int? currentIndex,
    required int? boardIndex,
    required int? alightIndex,
    required List<String> halteNames,
  }) {
    final out = <FollowAlertCandidate>[];
    final idx = currentIndex ?? nextIndex;

    if (boardIndex != null) {
      final rem = boardIndex - idx;
      if (rem >= 1 && rem <= approachRadius) {
        out.add(FollowAlertCandidate(
          type: FollowAlertType.approachingBoard,
          remaining: rem,
          halteName: _nameAt(halteNames, boardIndex),
        ));
      } else if (rem == 0) {
        // Bus tepat di halte naik — saatnya naik.
        out.add(FollowAlertCandidate(
          type: FollowAlertType.atBoard,
          remaining: 0,
          halteName: _nameAt(halteNames, boardIndex),
        ));
      }
    }

    // Peringatan turun hanya relevan setelah pengguna naik (melewati halte naik).
    if (boardIndex != null &&
        alightIndex != null &&
        currentIndex != null &&
        currentIndex > boardIndex) {
      final rem = alightIndex - idx;
      if (rem >= 1 && rem <= approachRadius) {
        out.add(FollowAlertCandidate(
          type: FollowAlertType.approachingAlight,
          remaining: rem,
          halteName: _nameAt(halteNames, alightIndex),
        ));
      } else if (rem == 0) {
        out.add(FollowAlertCandidate(
          type: FollowAlertType.atAlight,
          remaining: 0,
          halteName: _nameAt(halteNames, alightIndex),
        ));
      }
    }

    return out;
  }

  /// Mencocokkan leg rute yang sedang dinaiki/dituju bus [corridor]/[arahKey]
  /// pada posisi [idx] (indeks halte). Mengembalikan halte naik & turun, atau
  /// `null` bila tidak ada leg yang relevan (mis. bus tanpa rute atau sudah
  /// melewati halte turun).
  static ({int board, int alight})? matchBoardingLeg({
    required Iterable<TripLeg> legs,
    required String corridor,
    required String arahKey,
    required int idx,
  }) {
    TripLeg? next;
    TripLeg? passed;
    for (final leg in legs) {
      if (leg.corridor != corridor || leg.arahKey != arahKey) continue;
      if (leg.boardIndex >= idx) {
        // Leg halte naik yang masih di depan bus (pilih yang terdekat).
        if (next == null || leg.boardIndex < next.boardIndex) next = leg;
      } else {
        // Leg yang halte naiknya sudah dilewati (pilih yang paling baru).
        if (passed == null || leg.boardIndex > passed.boardIndex) passed = leg;
      }
    }
    final chosen = next ?? passed;
    if (chosen == null) return null;
    // Bus sudah melewati halte turun → tidak ada lagi yang perlu diberi tahu.
    if (chosen.alightIndex - idx < -1) return null;
    return (board: chosen.boardIndex, alight: chosen.alightIndex);
  }

  static String _nameAt(List<String> names, int index) =>
      (index >= 0 && index < names.length) ? names[index] : '';
}