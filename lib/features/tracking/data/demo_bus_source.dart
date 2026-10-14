import 'dart:async';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'bus_model.dart';
import 'bus_source.dart';
import 'halte_data.dart';

/// Sumber data bus palsu untuk pengembangan/demo.
///
/// Membangkitkan sejumlah bus yang bergerak menyusuri urutan halte NYATA
/// (dari [HalteDataset]) sehingga seluruh fitur UI — daftar bus terdekat,
/// timeline halte, ikuti bus, dan perencana rute — dapat diuji kapan saja
/// tanpa koneksi ke server (mis. di luar jam operasional).
class DemoBusSource implements BusSource {
  DemoBusSource({this.tick = const Duration(seconds: 3)});

  /// Interval pembaruan posisi bus.
  final Duration tick;

  final _busController = StreamController<List<Bus>>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  final List<_DemoBus> _buses = [];
  Timer? _timer;
  bool _disposed = false;

  @override
  Stream<List<Bus>> get busStream => _busController.stream;

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  void connect() {
    if (_disposed) return;
    _emitStatus(ConnectionStatus.connecting);
    _init();
  }

  Future<void> _init() async {
    try {
      final dataset = await loadHalteDataset();
      if (_disposed) return;
      _seed(dataset);
      _emit();
      _emitStatus(ConnectionStatus.connected);
      _timer = Timer.periodic(tick, (_) {
        for (final bus in _buses) {
          bus.advance();
        }
        _emit();
      });
    } catch (_) {
      if (!_disposed) _emitStatus(ConnectionStatus.disconnected);
    }
  }

  void _seed(HalteDataset dataset) {
    const corridors = ['K1', 'K2', 'K3', 'K4', 'K5', 'K6'];

    // Beberapa bus per arah, disebar merata di sepanjang rute sehingga setiap
    // halte naik (untuk fitur "cari tujuan") hampir selalu punya bus terdekat.
    const busesPerDirection = 3;
    var busNumber = 1;

    for (final kode in corridors) {
      final stops = dataset.forCorridor(kode);
      if (stops == null) continue;

      for (final entry in stops.arah.entries) {
        final halte = entry.value.halte;
        if (halte.length < 2) continue;

        for (var i = 0; i < busesPerDirection; i++) {
          final startIndex =
              (i * halte.length / busesPerDirection).floor().toDouble();
          _buses.add(_DemoBus(
            number: '${busNumber++}',
            corridor: stops.kode.trim().toUpperCase(),
            directionKey: entry.key,
            direction: entry.value,
            index: startIndex,
            speedKmh: 18 + ((busNumber + i) % 4) * 3,
          ));
        }
      }
    }
  }

  void _emit() {
    if (_busController.isClosed) return;
    _busController.add(
      _buses.map((b) => b.toBus()).toList(growable: false),
    );
  }

  void _emitStatus(ConnectionStatus status) {
    if (!_statusController.isClosed) _statusController.add(status);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _busController.close();
    _statusController.close();
  }
}

/// Satu bus demo yang bergerak maju menyusuri daftar halte arahnya.
class _DemoBus {
  final String number;
  final String corridor;
  final String directionKey;
  final CorridorDirection direction;
  final double speedKmh;

  /// Posisi sebagai indeks pecahan pada daftar halte (0..length-1).
  double index;

  _DemoBus({
    required this.number,
    required this.corridor,
    required this.directionKey,
    required this.direction,
    required this.index,
    required this.speedKmh,
  });

  void advance() {
    const stepPerTick = 0.22;
    index += stepPerTick;
    final maxIndex = (direction.halte.length - 1).toDouble();
    if (index >= maxIndex) index -= maxIndex; // looping kembali ke awal
  }

  Bus toBus() {
    final pos = _interpolate();
    return Bus(
      number: number,
      lat: pos.latitude,
      lng: pos.longitude,
      corridor: corridor,
      route: '${direction.halte.first.nama} - ${direction.halte.last.nama}',
      heading: _heading(),
      speedKmh: speedKmh,
      lastUpdate: DateTime.now().toUtc(),
    );
  }

  LatLng _interpolate() {
    final points = direction.halte;
    final i = index.floor().clamp(0, points.length - 1);
    final j = (i + 1).clamp(0, points.length - 1);
    final t = (index - i).clamp(0.0, 1.0);
    final a = points[i].pos;
    final b = points[j].pos;
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  double _heading() {
    final points = direction.halte;
    final i = index.floor().clamp(0, points.length - 1);
    final j = (i + 1).clamp(0, points.length - 1);
    if (i == j) return 0;
    final a = points[i].pos;
    final b = points[j].pos;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180 / math.pi;
    return (brng + 360) % 360;
  }
}
