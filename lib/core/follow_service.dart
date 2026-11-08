import 'dart:convert';

import 'package:flutter/services.dart';

import '../features/tracking/data/halte_data.dart';

/// Pembungkus MethodChannel ke [id.dwiky.transpadang_live/follow] (Android).
///
/// Menjalankan / menghentikan "follow bus" via foreground service native
/// ([FollowService] di sisi Android) yang menampilkan notifikasi ongoing
/// berisi halte berikutnya, ETA, dan progres.
class FollowService {
  FollowService._();

  static const MethodChannel _channel =
      MethodChannel('id.dwiky.transpadang_live/follow');

  /// Status deteksi otomatis dari layanan native.
  static const String boardingFollowing = 'following';
  static const String boardingOnboard = 'onboard';
  static const String boardingAlighted = 'alighted';

  /// Mendengarkan perubahan status naik/turun dari layanan native.
  /// [ended] bernilai true bila sesi follow berhenti sendiri (sudah turun).
  static void listenBoardingStatus(
    void Function(String status, bool ended) onChanged,
  ) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'boardingStatus' && call.arguments is Map) {
        final args = call.arguments as Map;
        onChanged(
          (args['status'] ?? boardingFollowing).toString(),
          args['ended'] == true,
        );
      }
      return null;
    });
  }

  static void stopListeningBoardingStatus() {
    _channel.setMethodCallHandler(null);
  }

  /// Meminta izin notifikasi (relevan Android 13+/API 33+).
  /// Mengembalikan `true` bila diizinkan (atau tak perlu diminta).
  static Future<bool> requestNotificationPermission() async {
    try {
      return await _channel
              .invokeMethod<bool>('requestNotificationPermission') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Info bus yang sedang diikuti (untuk memulihkan indikator setelah app
  /// di-restart). Mengembalikan null bila tidak ada sesi aktif.
  static Future<({String corridor, String busNumber, String status})?>
      getFollowed() async {
    try {
      final value = await _channel.invokeMethod<Object?>('getFollowed');
      if (value is Map) {
        final corridor = (value['corridor'] ?? '').toString();
        final busNumber = (value['busNumber'] ?? '').toString();
        final status = (value['status'] ?? boardingFollowing).toString();
        if (corridor.isNotEmpty) {
          return (corridor: corridor, busNumber: busNumber, status: status);
        }
      }
      return null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Mulai mengikuti satu bus. [haltes] adalah urutan halte arah yang sedang
  /// ditempuh (pergi/pulang). [accentColor] adalah warna ARGB badge koridor
  /// (dari `corridorColor`) agar notifikasi native memakai warna yang sama
  /// tanpa menduplikasi tabel warna di Kotlin.
  static Future<void> startFollow({
    required String corridor,
    required String busNumber,
    required String origin,
    required String destination,
    required String route,
    required String direction,
    required List<Halte> haltes,
    required int accentColor,
    required Map<String, String> labels,
    bool autoStopOnAlight = true,
  }) async {
    await _channel.invokeMethod('startFollow', {
      'corridor': corridor,
      'busNumber': busNumber,
      'origin': origin,
      'destination': destination,
      'route': route,
      'direction': direction,
      'color': accentColor,
      'labels': jsonEncode(labels),
      'autoStopOnAlight': autoStopOnAlight,
      'haltes': [
        for (final h in haltes)
          {
            'nama': h.nama,
            'lat': h.pos.latitude,
            'lng': h.pos.longitude,
          },
      ],
    });
  }

  static Future<void> stopFollow() async {
    try {
      await _channel.invokeMethod('stopFollow');
    } on PlatformException {
      // Abaikan bila belum ada servis aktif.
    } on MissingPluginException {
      // Abaikan.
    }
  }

  /// Menampilkan notifikasi sesaat (dengan suara & getar) untuk peristiwa
  /// kedatangan bus, mis. bus di-pin, tinggal 1-2 halte lagi, atau saatnya
  /// naik/turun. [id] dibedakan per jenis acara agar notifikasi tidak saling
  /// menimpa.
  static Future<void> showEventNotification({
    required String title,
    required String body,
    int id = 9101,
    String? channelName,
    String? channelDescription,
  }) async {
    try {
      await _channel.invokeMethod('showEventNotification', {
        'title': title,
        'body': body,
        'id': id,
        if (channelName != null) 'channelName': channelName,
        if (channelDescription != null)
          'channelDescription': channelDescription,
      });
    } on PlatformException {
      // Abaikan bila layer notifikasi native belum siap.
    } on MissingPluginException {
      // Abaikan.
    }
  }
}
