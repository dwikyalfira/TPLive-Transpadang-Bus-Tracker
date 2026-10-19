import 'package:flutter_test/flutter_test.dart';
import 'package:transpadang_live/core/config.dart';

/// Waktu [hour]:[minute] WIB sebagai [DateTime] UTC.
DateTime _wib(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 10, 19, hour, minute)
        .subtract(const Duration(hours: AppConfig.wibOffsetHours));

void main() {
  test('jam operasional 06.00-19.00 WIB', () {
    expect(AppConfig.operationalStartHour, 6);
    expect(AppConfig.operationalEndHour, 19);

    // Sebelum buka & tepat saat tutup -> di luar jam operasional.
    expect(AppConfig.isOutsideOperationalHours(_wib(5, 59)), isTrue);
    // 06.00 sudah buka, 18.59 masih buka, 19.00 sudah tutup.
    expect(AppConfig.isOutsideOperationalHours(_wib(6)), isFalse);
    expect(AppConfig.isOutsideOperationalHours(_wib(18, 59)), isFalse);
    expect(AppConfig.isOutsideOperationalHours(_wib(19)), isTrue);
  });
}
