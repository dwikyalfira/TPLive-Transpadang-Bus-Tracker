import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config.dart';
import 'bus_model.dart';
import 'bus_source.dart';

export 'bus_source.dart' show ConnectionStatus;

/// Sumber data realtime posisi bus via WebSocket.
///
/// Menangani koneksi tunggal, auto-reconnect (exponential backoff + jitter),
/// langganan `subscribeAll`, serta jeda saat aplikasi di background.
class TransWsDataSource implements BusSource {
  TransWsDataSource({this.url = AppConfig.wsUrl});

  final String url;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  AppLifecycleListener? _lifecycle;
  int _attempt = 0;
  bool _disposed = false;
  bool _paused = false;
  List<Bus> _lastBuses = const [];

  final _busController = StreamController<List<Bus>>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  @override
  Stream<List<Bus>> get busStream => _busController.stream;

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  List<Bus> get lastBuses => _lastBuses;

  /// Mulai koneksi dan pantau siklus hidup aplikasi.
  @override
  void connect() {
    if (_disposed) return;
    _open();
  }

  void _open() {
    if (_disposed || _paused) return;

    _emitStatus(ConnectionStatus.connecting);

    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;

      channel.ready.then((_) {
        if (_disposed || _channel != channel) return;
        _attempt = 0;
        _emitStatus(ConnectionStatus.connected);
        _sendSubscribeAll();
      }).catchError((_) {
        if (_channel == channel) _scheduleReconnect();
      });

      _sub = channel.stream.listen(
        _onData,
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _sendSubscribeAll() {
    _channel?.sink.add(AppConfig.subscribeAllMessage);
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final type = decoded['type'];
      if (type == 'allBusLocation' || type == 'busLocationByKoridor') {
        final data = decoded['data'];
        if (data is! List) return;
        final buses = data
            .whereType<Map>()
            .map((e) => Bus.fromJson(e.cast<String, dynamic>()))
            .toList(growable: false);
        _lastBuses = buses;
        if (!_busController.isClosed) _busController.add(buses);
      }
    } catch (_) {
      // Abaikan pesan yang tidak dapat di-parse.
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _paused) return;
    _teardownChannel();
    _emitStatus(ConnectionStatus.connecting);
    _attempt++;
    final baseSeconds = (1 << _attempt.clamp(0, 5)).clamp(1, 30);
    final jitterSeconds = baseSeconds * 0.25 * Random().nextDouble();
    final delay = Duration(
        milliseconds:
            (baseSeconds * 1000).round() + (jitterSeconds * 1000).round());
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _open);
  }

  void _closeSocket(ConnectionStatus status) {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _teardownChannel();
    _emitStatus(status);
  }

  void _teardownChannel() {
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close(ws_status.normalClosure);
    _channel = null;
  }

  void _emitStatus(ConnectionStatus status) {
    if (!_statusController.isClosed) _statusController.add(status);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _reconnectTimer?.cancel();
    _teardownChannel();
    _lifecycle?.dispose();
    _busController.close();
    _statusController.close();
  }
}