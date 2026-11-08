import 'package:flutter_test/flutter_test.dart';
import 'package:transpadang_live/core/theme/app_motion.dart';

void main() {
  test('rubberBand mengikuti faktor di awal tarikan', () {
    expect(
      AppMotion.rubberBand(1),
      closeTo(AppMotion.rubberBandFactor, 0.01),
    );
  });

  test('rubberBand naik terus namun tidak melewati batas', () {
    expect(AppMotion.rubberBand(0), 0);
    expect(AppMotion.rubberBand(400), greaterThan(AppMotion.rubberBand(200)));
    expect(AppMotion.rubberBand(1e6), lessThan(AppMotion.rubberBandLimit));
  });

  test('rubberBandInverse mengembalikan jarak jari semula', () {
    for (final distance in [1.0, 40.0, 200.0]) {
      expect(
        AppMotion.rubberBandInverse(AppMotion.rubberBand(distance)),
        closeTo(distance, 0.001),
      );
    }
  });
}
