import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../../../core/config.dart';
import 'bus_model.dart';
import 'bus_source.dart';
import 'ws_transport.dart';

export 'bus_source.dart' show ConnectionStatus;

/// Sumber data realtime posisi bus via WebSocket.
///
/// Menangani koneksi tunggal, auto-reconnect (exponential backoff + jitter),
/// langganan `subscribeAll`, serta pengawas keaktifan koneksi.
class TransWsDataSource implements BusSource {
  TransWsDataSource({
    this.url = AppConfig.wsUrl,
    WsTransportFactory? transportFactory,
    DateTime Function()? now,
    Random? random,
  })  : _transportFactory = transportFactory ?? defaultWsTransportFactory,
        _now = now ?? DateTime.now,
        _random = random ?? Random();

  final String url;
  final WsTransportFactory _transportFactory;
  final DateTime Function() _now;
  final Random _random;

  WsTransport? _transport;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  Timer? _watchdog;
  AppLifecycleListener? _lifecycle;
  int _attempt = 0;
  int _consecutiveFailures = 0;
  bool _disposed = false;
  DateTime? _lastMessageAt;
  DateTime? _connectedAt;
  ConnectionStatus _status = ConnectionStatus.connecting;

  /// Setelah sekian percobaan gagal berturut-turut (tanpa satu pun pesan dari
  /// server), status berubah menjadi [ConnectionStatus.disconnected] agar UI
  /// tidak selamanya menampilkan "menyambung ulang".
  static const int _disconnectedAfterFailures = 5;

  /// Selang pemeriksaan keaktifan koneksi.
  static const Duration _watchdogInterval = Duration(seconds: 5);

  /// Batas senyap setelah pernah menerima data sebelum koneksi dianggap mati.
  static const Duration _silenceTimeout = Duration(seconds: 25);

  /// Batas tunggu data pertama pada koneksi yang baru terbuka.
  static const Duration _initialDataTimeout = Duration(seconds: 30);

  final _busController = StreamController<List<Bus>>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  @override
  Stream<List<Bus>> get busStream => _busController.stream;

  /// Status saat ini langsung dikirim saat dilanggan, lalu diikuti perubahan
  /// berikutnya. Tanpa ini, emisi `connecting` pertama bisa hilang karena
  /// terjadi sebelum [StreamProvider] sempat berlangganan.
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

  /// Mulai koneksi, pantau siklus hidup aplikasi, dan jalankan pengawas keaktifan.
  @override
  void connect() {
    if (_disposed || _transport != null) return;
    _lifecycle ??= AppLifecycleListener(onResume: _checkLiveness);
    _emitStatus(ConnectionStatus.connecting);
    _open();
  }

  /// Pengawas hanya berjalan saat socket benar-benar terbuka, agar tidak ada
  /// timer yang hidup selagi sekadar mencoba menyambung (atau di pengujian).
  void _startWatchdog() {
    _watchdog ??= Timer.periodic(_watchdogInterval, (_) => _checkLiveness());
  }

  /// Pengawas: bila socket terbuka tetapi lama tidak ada pesan masuk, koneksi
  /// dianggap mati diam-diam (mis. setelah app lama di background atau perangkat
  /// berpindah jaringan). Tanpa ini, penanda status tetap "terhubung" padahal
  /// daftar bus kosong selamanya—satu-satunya pemulihan adalah menutup paksa app.
  void _checkLiveness() {
    if (_disposed || _transport == null) return;
    final now = _now();
    final last = _lastMessageAt;
    // Di luar jam operasional server boleh diam; jangan sambung ulang terus.
    if (last == null && AppConfig.isOutsideOperationalHours(now)) return;
    final since = last ?? _connectedAt;
    if (since == null) return;
    final timeout = last == null ? _initialDataTimeout : _silenceTimeout;
    if (now.difference(since) > timeout) {
      _lastMessageAt = null;
      _connectedAt = now;
      _scheduleReconnect();
    }
  }

  void _open() {
    if (_disposed || _transport != null) return;

    _reconnectTimer = null;
    _connectedAt = _now();
    _lastMessageAt = null;

    try {
      final transport = _transportFactory(Uri.parse(url));
      _transport = transport;

      transport.ready.then((_) {
        if (_disposed || _transport != transport) return;
        _attempt = 0;
        _connectedAt = _now();
        _emitStatus(ConnectionStatus.connected);
        _sendSubscribeAll();
        _startWatchdog();
      }).catchError((_) {
        if (_disposed || _transport != transport) return;
        _scheduleReconnect();
      });

      _sub = transport.messages.listen(
        (raw) {
          if (_transport == transport) _onData(raw);
        },
        onError: (_) {
          if (_transport == transport) _scheduleReconnect();
        },
        onDone: () {
          if (_transport == transport) _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _sendSubscribeAll() {
    _transport?.send(AppConfig.subscribeAllMessage);
  }

  void _onData(dynamic raw) {
    _lastMessageAt = _now();
    // Pesan apa pun (termasuk sapaan "info") membuktikan koneksi hidup.
    _consecutiveFailures = 0;
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final type = decoded['type'];
      if (type == 'allBusLocation') {
        final data = decoded['data'];
        if (data is! List) return;
        final buses = data
            .whereType<Map>()
            .map((e) => Bus.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false);
        if (!_busController.isClosed) _busController.add(buses);
      }
    } catch (_) {
      // Abaikan pesan yang tidak dapat di-parse.
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    // Satu kegagalan bisa memicu beberapa callback (ready, onError, onDone).
    // Cukup satu timer reconnect yang aktif.
    if (_reconnectTimer != null) return;

    _teardownTransport();
    _attempt++;
    _consecutiveFailures++;
    _emitStatus(_consecutiveFailures >= _disconnectedAfterFailures
        ? ConnectionStatus.disconnected
        : ConnectionStatus.reconnecting);

    final baseSeconds = (1 << _attempt.clamp(0, 5).toInt()).clamp(1, 30);
    final jitterSeconds = baseSeconds * 0.25 * _random.nextDouble();
    final delay = Duration(
        milliseconds:
            (baseSeconds * 1000).round() + (jitterSeconds * 1000).round());
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      _open();
    });
  }

  void _teardownTransport() {
    _watchdog?.cancel();
    _watchdog = null;
    _sub?.cancel();
    _sub = null;
    final transport = _transport;
    _transport = null;
    if (transport != null) {
      unawaited(transport.close(ws_status.normalClosure));
    }
  }

  void _emitStatus(ConnectionStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _teardownTransport();
    _lifecycle?.dispose();
    _busController.close();
    _statusController.close();
  }
}
