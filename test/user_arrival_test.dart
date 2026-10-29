import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transpadang_live/features/tracking/domain/user_arrival.dart';

/// Bus di (-0.90, 100.30); pengguna ~1,1 km di timurnya (-0.90, 100.31).
const _bus = LatLng(-0.90, 100.30);
const _userEast = LatLng(-0.90, 100.31);

void main() {
  test('bus yang jauh mendapat estimasi menit & jarak', () {
    final r = UserArrival.estimate(
      busPosition: _bus,
      user: _userEast,
      speedKmh: 20,
    )!;

    expect(r.distanceKm, closeTo(1.11, 0.05));
    // 1,11 km pada 20 km/j ≈ 3,3 menit.
    expect(r.etaMinutes, inInclusiveRange(3, 4));
    expect(r.hasEta, isTrue);
    expect(r.isHere, isFalse);
  });

  test('estimasi tidak bergantung arah gerak bus', () {
    // Dulu ada penyaring "bus menjauh" yang menyembunyikan estimasi; sekarang
    // angka tetap ada supaya tidak hilang-muncul antar layar.
    final r = UserArrival.estimate(
      busPosition: _bus,
      user: _userEast,
      speedKmh: 20,
    )!;

    expect(r.etaMinutes, isNotNull);
    expect(r.hasEta, isTrue);
  });

  test('bus yang berhenti memakai kecepatan default', () {
    final stopped = UserArrival.estimate(
      busPosition: _bus,
      user: _userEast,
      speedKmh: 0,
    )!;
    final moving = UserArrival.estimate(
      busPosition: _bus,
      user: _userEast,
      speedKmh: 20,
    )!;

    expect(stopped.etaMinutes, moving.etaMinutes);
  });

  test('tanpa data kecepatan tetap dihitung', () {
    final r = UserArrival.estimate(busPosition: _bus, user: _userEast)!;

    expect(r.etaMinutes, isNotNull);
  });

  test('bus tepat di titik pengguna dianggap sudah dekat', () {
    final near = UserArrival.estimate(
      busPosition: _bus,
      user: const LatLng(-0.9001, 100.3001),
      speedKmh: 20,
    )!;
    expect(near.isHere, isTrue);
    expect(near.etaMinutes, 0);
    expect(near.hasEta, isTrue);

    // 1,1 km bukan "sudah dekat".
    final far = UserArrival.estimate(
      busPosition: _bus,
      user: _userEast,
      speedKmh: 20,
    )!;
    expect(far.isHere, isFalse);
  });

  test('jarak dan menit bertambah saat bus makin jauh', () {
    final near = UserArrival.estimate(
      busPosition: _bus,
      user: _userEast,
      speedKmh: 20,
    )!;
    final far = UserArrival.estimate(
      busPosition: _bus,
      user: const LatLng(-0.90, 100.33),
      speedKmh: 20,
    )!;

    expect(far.distanceKm, greaterThan(near.distanceKm));
    expect(far.etaMinutes!, greaterThan(near.etaMinutes!));
  });
}
