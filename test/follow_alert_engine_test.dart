import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/features/tracking/data/halte_data.dart';
import 'package:transpadang_live/features/tracking/domain/follow_alert_engine.dart';
import 'package:transpadang_live/features/trip/domain/trip_planner.dart';

void main() {
  const names = <String>[
    'Simpang Ketaping',
    'Simpang Pilakut',
    'Mega Permai',
    'SMP Muhammadiyah 7',
    'SMA 5 Padang',
    'Politeknik Padang',
  ];

  const halte = Halte(nama: 'Halte', pos: LatLng(-0.9, 100.4));

  TripLeg leg({
    required String arahKey,
    required int board,
    required int alight,
  }) {
    return TripLeg(
      corridor: 'K6',
      arahKey: arahKey,
      directionLabel: 'Pergi',
      board: halte,
      alight: halte,
      boardIndex: board,
      alightIndex: alight,
      stopCount: alight - board,
      rideKm: 1,
      rideMinutes: 5,
    );
  }

  group('FollowAlertEngine.evaluate', () {
    test('tidak ada kandidat saat bus masih jauh (>2 halte)', () {
      final out = FollowAlertEngine.evaluate(
        nextIndex: 0,
        currentIndex: null,
        boardIndex: 4,
        alightIndex: 5,
        halteNames: names,
      );
      expect(out, isEmpty);
    });

    test('peringatan naik saat bus tinggal 2 halte menuju halte naik', () {
      final out = FollowAlertEngine.evaluate(
        nextIndex: 3,
        currentIndex: 2,
        boardIndex: 4,
        alightIndex: 5,
        halteNames: names,
      );
      expect(out, hasLength(1));
      expect(out.single.type, FollowAlertType.approachingBoard);
      expect(out.single.remaining, 2);
      expect(out.single.halteName, 'SMA 5 Padang');
    });

    test('peringatan naik saat bus tinggal 1 halte menuju halte naik', () {
      final out = FollowAlertEngine.evaluate(
        nextIndex: 4,
        currentIndex: 3,
        boardIndex: 4,
        alightIndex: 5,
        halteNames: names,
      );
      expect(out.single.type, FollowAlertType.approachingBoard);
      expect(out.single.remaining, 1);
    });

    test('saatnya naik ketika bus tiba di halte naik', () {
      final out = FollowAlertEngine.evaluate(
        nextIndex: 4,
        currentIndex: 4,
        boardIndex: 4,
        alightIndex: 5,
        halteNames: names,
      );
      expect(out.single.type, FollowAlertType.atBoard);
      expect(out.single.halteName, 'SMA 5 Padang');
    });

    test('sebelum melewati halte naik, hanya peringatan naik yang muncul', () {
      final out = FollowAlertEngine.evaluate(
        nextIndex: 3,
        currentIndex: 3,
        boardIndex: 4,
        alightIndex: 5,
        halteNames: names,
      );
      expect(out, hasLength(1));
      expect(out.single.type, FollowAlertType.approachingBoard);
    });

    test(
        'bus sudah lewat halte naik: tidak menyuruh naik, peringatan turun '
        'jalan terus', () {
      final out = FollowAlertEngine.evaluate(
        nextIndex: 5,
        currentIndex: 5,
        boardIndex: 4,
        alightIndex: 5,
        halteNames: names,
      );
      expect(out, hasLength(1));
      expect(out.single.type, FollowAlertType.atAlight);
    });

    test('peringatan turun saat bus tinggal 2 halte dari halte turun', () {
      final out = FollowAlertEngine.evaluate(
        nextIndex: 3,
        currentIndex: 3,
        boardIndex: 2,
        alightIndex: 5,
        halteNames: names,
      );
      expect(out, hasLength(1));
      expect(out.single.type, FollowAlertType.approachingAlight);
      expect(out.single.remaining, 2);
    });

    test('saatnya turun ketika bus tiba di halte turun', () {
      final out = FollowAlertEngine.evaluate(
        nextIndex: 4,
        currentIndex: 4,
        boardIndex: 2,
        alightIndex: 4,
        halteNames: names,
      );
      expect(out.single.type, FollowAlertType.atAlight);
    });

    test('tidak ada peringatan turun sebelum melewati halte naik', () {
      final out = FollowAlertEngine.evaluate(
        nextIndex: 1,
        currentIndex: 1,
        boardIndex: 5,
        alightIndex: 6,
        halteNames: names,
      );
      expect(out, isEmpty);
    });

    test('tidak ada kandidat bila board/alight tidak diketahui', () {
      final out = FollowAlertEngine.evaluate(
        nextIndex: 3,
        currentIndex: 2,
        boardIndex: null,
        alightIndex: null,
        halteNames: names,
      );
      expect(out, isEmpty);
    });

    test('dedupeKey stabil agar notifikasi sekali kirim', () {
      final a = FollowAlertEngine.evaluate(
        nextIndex: 3,
        currentIndex: 3,
        boardIndex: 4,
        alightIndex: 5,
        halteNames: names,
      );
      final b = FollowAlertEngine.evaluate(
        nextIndex: 3,
        currentIndex: 3,
        boardIndex: 4,
        alightIndex: 5,
        halteNames: names,
      );
      expect(a.single.dedupeKey, b.single.dedupeKey);
    });
  });

  group('FollowAlertEngine.matchBoardingLeg', () {
    test('belum naik: memilih leg terdekat di depan bus', () {
      final lgs = [
        leg(arahKey: 'pergi', board: 4, alight: 5),
        leg(arahKey: 'pulang', board: 0, alight: 1),
      ];
      final m = FollowAlertEngine.matchBoardingLeg(
        legs: lgs,
        corridor: 'K6',
        arahKey: 'pergi',
        idx: 1,
      );
      expect(m, isNotNull);
      expect(m!.board, 4);
      expect(m.alight, 5);
    });

    test('sudah naik: memakai leg yang halte naiknya baru dilewati', () {
      final lgs = [
        leg(arahKey: 'pergi', board: 2, alight: 5),
        leg(arahKey: 'pergi', board: 1, alight: 3),
      ];
      final m = FollowAlertEngine.matchBoardingLeg(
        legs: lgs,
        corridor: 'K6',
        arahKey: 'pergi',
        idx: 3,
      );
      expect(m, isNotNull);
      expect(m!.board, 2);
      expect(m.alight, 5);
    });

    test('koridor tak cocok: null', () {
      final lgs = [
        leg(arahKey: 'pergi', board: 4, alight: 5),
      ];
      final m = FollowAlertEngine.matchBoardingLeg(
        legs: lgs,
        corridor: 'K1',
        arahKey: 'pergi',
        idx: 0,
      );
      expect(m, isNull);
    });

    test('sudah melewati halte turun: null', () {
      final lgs = [
        leg(arahKey: 'pergi', board: 1, alight: 3),
      ];
      final m = FollowAlertEngine.matchBoardingLeg(
        legs: lgs,
        corridor: 'K6',
        arahKey: 'pergi',
        idx: 5,
      );
      expect(m, isNull);
    });
  });
}