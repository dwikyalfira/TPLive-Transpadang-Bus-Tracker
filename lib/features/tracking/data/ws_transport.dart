import 'dart:async';

import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Koneksi WebSocket minimal yang dibutuhkan [TransWsDataSource].
///
/// Dipisah sebagai antarmuka supaya logika status/reconnect dapat diuji tanpa
/// membuka jaringan sungguhan (lihat `test/trans_ws_datasource_test.dart`).
abstract class WsTransport {
  /// Pesan masuk dari server (biasanya `String`).
  Stream<dynamic> get messages;

  /// Selesai ketika handshake WebSocket berhasil.
  Future<void> get ready;

  /// Mengirim satu pesan teks.
  void send(String message);

  /// Menutup koneksi.
  Future<void> close([int? code, String? reason]);
}

/// Membuat [WsTransport] untuk [uri].
typedef WsTransportFactory = WsTransport Function(Uri uri);

/// Implementasi produksi: [WebSocketChannel] dari `web_socket_channel`.
class WebSocketTransport implements WsTransport {
  WebSocketTransport(Uri uri) : _channel = WebSocketChannel.connect(uri);

  final WebSocketChannel _channel;

  @override
  Stream<dynamic> get messages => _channel.stream;

  @override
  Future<void> get ready => _channel.ready;

  @override
  void send(String message) => _channel.sink.add(message);

  @override
  Future<void> close([int? code, String? reason]) =>
      _channel.sink.close(code ?? ws_status.normalClosure, reason);
}

/// Factory default untuk [TransWsDataSource].
WsTransport defaultWsTransportFactory(Uri uri) => WebSocketTransport(uri);
