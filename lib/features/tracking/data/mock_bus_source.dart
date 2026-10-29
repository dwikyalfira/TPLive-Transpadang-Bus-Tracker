import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../domain/geo_utils.dart' as geo;
import 'bus_model.dart';
import 'bus_source.dart';
import 'halte_data.dart';

/// Sumber data bus **tiruan** untuk demo, pengembangan, dan uji tampilan.
///
/// Bus digerakkan menyusuri urutan halte tiap koridor (pergi & pulang) dengan
/// kecepatan tetap, lalu posisinya diperbarui tiap [tick]. Karena titik
/// jalannya adalah halte asli, semua fitur yang bergantung pada posisi
/// (jarak ke halte, timeline halte, "halte berikutnya", kartu di-pin) tetap
/// berperilaku wajar — tidak seperti data acak.
///
/// Diaktifkan lewat `--dart-define=MOCK_BUS=true` (lihat
/// `AppConfig.useMockBus`); aplikasi rilis tanpa flag itu sama sekali tidak
/// memakai kelas ini.
class MockBusSource implements BusSource {
  MockBusSource({
    HalteDataset? dataset,
    this.tick = const Duration(seconds: 2),
    this.busesPerDirection = 2,
  }) : _dataset = dataset;

  /// Dataset siap pakai (dipakai pengujian). Bila null, `assets/halte.json`
  /// dimuat sendiri saat [connect].
  final HalteDataset? _dataset;

  /// Selang pembaruan posisi.
  final Duration tick;

  /// Jumlah bus tiruan per arah koridor.
  final int busesPerDirection;

  final _busController = StreamController<List<Bus>>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  final List<_MockBus> _buses = <_MockBus>[];
  Timer? _timer;
  bool _started = false;
  bool _disposed = false;
  ConnectionStatus _status = ConnectionStatus.connecting;

  @override
  Stream<List<Bus>> get busStream => _busController.stream;

  /// Status saat ini langsung dikirim saat dilanggan, lalu perubahannya.
  @override
  Stream<ConnectionStatus> get statusStream =>
      Stream<ConnectionStatus>.multi((controller) {
        controller.add(_status);
        final sub = _statusController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = sub.cancel;
      });

  @override
  void connect() {
    if (_disposed || _started) return;
    _started = true;
    _emitStatus(ConnectionStatus.connected);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    HalteDataset? dataset = _dataset;
    if (dataset == null) {
      try {
        dataset = await loadHalteDataset();
      } catch (_) {
        // Aset tidak terbaca: tetap kirim daftar kosong agar UI tidak macet
        // di status "menyambung".
        dataset = null;
      }
    }
    if (_disposed) return;
    if (dataset != null) _build(dataset);
    _emit();
    _timer = Timer.periodic(tick, (_) => _advance());
  }

  /// Menyiapkan bus tiruan: [busesPerDirection] bus per arah, tersebar merata
  /// di sepanjang jalur.
  void _build(HalteDataset dataset) {
    final codes = dataset.corridors.keys.toList()..sort();
    for (final code in codes) {
      final stops = dataset.corridors[code]!;
      for (final entry in stops.arah.entries) {
        final path = _Path.of(entry.value.halte);
        if (path == null) continue;
        for (var i = 0; i < busesPerDirection; i++) {
          _buses.add(_MockBus(
            number: '${code.replaceAll(RegExp(r'[^0-9]'), '')}${i + 1}',
            corridor: code,
            route: entry.value.label,
            path: path,
            // Tersebar merata, lalu bergerak dengan kecepatan berbeda-beda
            // supaya tampilan tidak terlihat seperti barisan rapi.
            meters: path.totalMeters * i / busesPerDirection,
            speedKmh: 18 + ((i * 7) % 11),
          ));
        }
      }
    }
  }

  void _advance() {
    if (_disposed) return;
    final seconds = tick.inMilliseconds / 1000.0;
    for (final bus in _buses) {
      bus.meters += bus.speedKmh * 1000 / 3600 * seconds;
      // Sampai ujung jalur: mulai lagi dari awal (bus berikutnya).
      if (bus.meters > bus.path.totalMeters) {
        bus.meters -= bus.path.totalMeters;
      }
    }
    _emit();
  }

  void _emit() {
    if (_busController.isClosed) return;
    final now = DateTime.now().toUtc();
    _busController.add([
      for (final bus in _buses)
        Bus(
          number: bus.number,
          lat: bus.position.latitude,
          lng: bus.position.longitude,
          corridor: bus.corridor,
          route: bus.route,
          heading: bus.heading,
          speedKmh: bus.speedKmh,
          // Selalu segar: data tiruan tidak boleh dianggap basi (>5 menit).
          lastUpdate: now,
        ),
    ]);
  }

  void _emitStatus(ConnectionStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _busController.close();
    _statusController.close();
  }
}

/// Satu bus tiruan beserta posisinya di sepanjang jalur.
class _MockBus {
  _MockBus({
    required this.number,
    required this.corridor,
    required this.route,
    required this.path,
    required this.meters,
    required this.speedKmh,
  });

  final String number;
  final String corridor;
  final String route;
  final _Path path;
  final double speedKmh;

  /// Jarak yang sudah ditempuh dari awal jalur (meter).
  double meters;

  LatLng get position => path.positionAt(meters);

  double get heading => path.headingAt(meters);
}

/// Jalur satu arah: titik-titik halte + panjang kumulatifnya.
class _Path {
  _Path._(this.points, this.cumulative, this.totalMeters);

  final List<LatLng> points;
  final List<double> cumulative;
  final double totalMeters;

  /// Null bila titiknya kurang dari dua atau seluruhnya berimpit.
  static _Path? of(List<Halte> halte) {
    if (halte.length < 2) return null;
    final points = [for (final h in halte) h.pos];
    final cumulative = List<double>.filled(points.length, 0);
    for (var i = 1; i < points.length; i++) {
      cumulative[i] = cumulative[i - 1] +
          geo.distanceKm(points[i - 1], points[i]) *
              1000;
    }
    if (cumulative.last <= 0) return null;
    return _Path._(points, cumulative, cumulative.last);
  }

  LatLng positionAt(double meters) {
    final s = meters.clamp(0.0, totalMeters);
    for (var i = 0; i < points.length - 1; i++) {
      if (s > cumulative[i + 1]) continue;
      final segment = cumulative[i + 1] - cumulative[i];
      final t = segment <= 0 ? 0.0 : (s - cumulative[i]) / segment;
      return LatLng(
        points[i].latitude + (points[i + 1].latitude - points[i].latitude) * t,
        points[i].longitude +
            (points[i + 1].longitude - points[i].longitude) * t,
      );
    }
    return points.last;
  }

  double headingAt(double meters) {
    final s = meters.clamp(0.0, totalMeters);
    for (var i = 0; i < points.length - 1; i++) {
      if (s > cumulative[i + 1]) continue;
      return geo.bearingDegrees(points[i], points[i + 1]);
    }
    return geo.bearingDegrees(points[points.length - 2], points.last);
  }
}
