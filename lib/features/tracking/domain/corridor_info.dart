import '../data/halte_data.dart';

/// Ringkasan informasi satu koridor untuk fitur "Info Koridor": jumlah bus
/// aktif saat ini, jumlah halte tiap arah (dan unik), serta terminus
/// asal→tujuan tiap arah.
///
/// Jumlah halte dihitung dari dataset statis ([CorridorStops]); jumlah bus
/// aktif berasal dari data WebSocket terkini.
class CorridorInfo {
  final String code;

  /// Nama rute resmi (dari field `route` bus), bila tersedia.
  final String? routeName;

  /// Banyak bus aktif pada koridor ini saat ini.
  final int activeBuses;

  final int stopsPergi;
  final int stopsPulang;

  /// Banyak halte unik (nama yang sama dihitung sekali) pada kedua arah.
  final int uniqueStops;

  final String? originPergi;
  final String? destinationPergi;
  final String? originPulang;
  final String? destinationPulang;

  const CorridorInfo({
    required this.code,
    required this.activeBuses,
    required this.stopsPergi,
    required this.stopsPulang,
    required this.uniqueStops,
    this.routeName,
    this.originPergi,
    this.destinationPergi,
    this.originPulang,
    this.destinationPulang,
  });

  /// Terminus asal & tujuan diambil dari elemen pertama & terakhir daftar halte
  /// masing-masing arah — urutan halte selalu dari asal menuju tujuan, dan
  /// konsisten dengan label arah pada dataset.
  factory CorridorInfo.of(
    String code,
    CorridorStops? stops,
    int activeBuses, {
    String? routeName,
  }) {
    final pergi = stops?.pergi?.halte ?? const [];
    final pulang = stops?.pulang?.halte ?? const [];

    final names = <String>{};
    for (final halte in [...pergi, ...pulang]) {
      final name = halte.nama.trim().toLowerCase();
      if (name.isNotEmpty) names.add(name);
    }

    return CorridorInfo(
      code: code,
      activeBuses: activeBuses,
      stopsPergi: pergi.length,
      stopsPulang: pulang.length,
      uniqueStops: names.length,
      routeName: routeName,
      originPergi: pergi.isEmpty ? null : pergi.first.nama,
      destinationPergi: pergi.isEmpty ? null : pergi.last.nama,
      originPulang: pulang.isEmpty ? null : pulang.first.nama,
      destinationPulang: pulang.isEmpty ? null : pulang.last.nama,
    );
  }

  int get totalStops => stopsPergi + stopsPulang;

  /// Terminus pada arah tertentu; `pergi` (default) atau `pulang`.
  String? originFor(bool pergi) => pergi ? originPergi : originPulang;
  String? destinationFor(bool pergi) =>
      pergi ? destinationPergi : destinationPulang;
}

/// Ringkasan seluruh jaringan TransPadang untuk tab "Semua".
class NetworkInfo {
  final int activeBuses;
  final int corridorCount;
  final int totalStops;
  final int uniqueStops;

  const NetworkInfo({
    required this.activeBuses,
    required this.corridorCount,
    required this.totalStops,
    required this.uniqueStops,
  });
}
