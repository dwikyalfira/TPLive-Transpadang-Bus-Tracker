import 'bus_model.dart';

/// Status koneksi sumber data bus.
enum ConnectionStatus {
  connecting,
  connected,
  reconnecting,
  disconnected,
  outsideHours,
}

/// Kontrak sumber data posisi bus realtime.
abstract class BusSource {
  /// Aliran daftar bus terbaru.
  Stream<List<Bus>> get busStream;

  /// Aliran status koneksi.
  Stream<ConnectionStatus> get statusStream;

  /// Mulai menghasilkan data.
  void connect();

  /// Bersihkan sumber daya.
  void dispose();
}
