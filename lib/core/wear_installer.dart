import 'package:flutter/services.dart';

/// Hasil pemasangan app Wear OS. [message] berisi kode (`apk_missing`,
/// `pair_failed`, `connect_failed`, `ok`) atau pesan error mentah dari ADB.
class WearInstallResult {
  final bool ok;
  final String message;

  const WearInstallResult({required this.ok, required this.message});
}

/// Alamat `host:port` yang sudah di-parse.
class HostPort {
  final String host;
  final int port;

  const HostPort(this.host, this.port);

  /// Mengurai teks seperti `192.168.1.20:37099`. Mengembalikan null bila
  /// formatnya tidak valid.
  static HostPort? parse(String input) {
    final text = input.trim();
    final idx = text.lastIndexOf(':');
    if (idx <= 0 || idx == text.length - 1) return null;
    final host = text.substring(0, idx).trim();
    final port = int.tryParse(text.substring(idx + 1).trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535) return null;
    return HostPort(host, port);
  }
}

/// Pembungkus MethodChannel ke [id.dwiky.transpadang_live/wear_install]
/// (Android): memasang app Wear OS ke jam lewat wireless debugging.
class WearInstaller {
  WearInstaller._();

  static const MethodChannel _channel =
      MethodChannel('id.dwiky.transpadang_live/wear_install');

  /// Apakah APK Wear dibundel di dalam app ini.
  static Future<bool> isApkBundled() async {
    try {
      return await _channel.invokeMethod<bool>('isApkBundled') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Pairing dengan [pair] memakai [code], lalu terhubung ke [connect] dan
  /// memasang app. Lama (puluhan detik); jangan dipanggil berulang.
  ///
  /// Bila [pair] dan [connect] null, alamat & port ditemukan otomatis lewat
  /// mDNS (hanya butuh [code]).
  ///
  /// [onStage] dipanggil tiap tahap dimulai (`discover_pair`, `pairing`,
  /// `discover_connect`, `connecting`, `installing`).
  static Future<WearInstallResult> pairAndInstall({
    HostPort? pair,
    required String code,
    HostPort? connect,
    void Function(String stage)? onStage,
  }) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stage' && call.arguments is String) {
        onStage?.call(call.arguments as String);
      }
      return null;
    });
    try {
      final value = await _channel.invokeMethod<Map<Object?, Object?>>(
        'pairAndInstall',
        {
          'host': pair?.host ?? '',
          'pairPort': pair?.port ?? 0,
          'code': code.trim(),
          'connectPort': connect?.port ?? 0,
        },
      );
      return WearInstallResult(
        ok: value?['ok'] == true,
        message: (value?['message'] ?? '').toString(),
      );
    } on PlatformException catch (e) {
      return WearInstallResult(ok: false, message: e.message ?? e.code);
    } on MissingPluginException {
      return const WearInstallResult(ok: false, message: 'unavailable');
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }
}
