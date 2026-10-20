import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transpadang_live/features/tracking/data/trans_ws_datasource.dart';
import 'package:transpadang_live/features/tracking/data/ws_transport.dart';

/// Transport palsu: handshake dan pesan dikendalikan langsung oleh test.
class _FakeTransport implements WsTransport {
  final _messages = StreamController<dynamic>();
  final _ready = Completer<void>();

  final List<String> sent = [];
  bool closed = false;

  @override
  Stream<dynamic> get messages => _messages.stream;

  @override
  Future<void> get ready => _ready.future;

  @override
  void send(String message) => sent.add(message);

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    if (!_messages.isClosed) await _messages.close();
  }

  void completeReady() => _ready.complete();

  void failReady([Object error = 'gagal']) => _ready.completeError(error);

  void add(dynamic message) => _messages.add(message);
}

String _snapshot({String bus = '65', String corridor = 'K3'}) => jsonEncode({
      'type': 'allBusLocation',
      'data': [
        {
          'bus': bus,
          'longitude': '-0.899045',
          'latitude': '100.38996444',
          'corridor': corridor,
          'direct': '100',
          'speed': '28',
          'route': 'RTH Imam Bonjol - Balaikota',
          'last_update': '2026-10-12 12:09:28',
        }
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('statusStream langsung mengirim status saat ini', () async {
    final source = TransWsDataSource(
      transportFactory: (_) => _FakeTransport(),
    );
    addTearDown(source.dispose);

    expect(await source.statusStream.first, ConnectionStatus.connecting);
  });

  test('handshake berhasil -> connected + subscribeAll', () {
    fakeAsync((async) {
      final fake = _FakeTransport();
      final source = TransWsDataSource(
        transportFactory: (_) => fake,
        random: Random(1),
      );
      final statuses = <ConnectionStatus>[];
      source.statusStream.listen(statuses.add);
      async.flushMicrotasks();

      source.connect();
      async.flushMicrotasks();
      fake.completeReady();
      async.flushMicrotasks();

      expect(statuses, contains(ConnectionStatus.connected));
      expect(fake.sent, ['{"type":"subscribeAll"}']);
      source.dispose();
    });
  });

  test('gagal berulang -> reconnecting lalu disconnected', () {
    fakeAsync((async) {
      final transports = <_FakeTransport>[];
      final source = TransWsDataSource(
        transportFactory: (_) {
          final fake = _FakeTransport();
          transports.add(fake);
          return fake;
        },
        random: Random(1),
      );
      final statuses = <ConnectionStatus>[];
      source.statusStream.listen(statuses.add);
      async.flushMicrotasks();

      source.connect();
      for (var i = 0; i < 5; i++) {
        async.flushMicrotasks();
        transports.last.failReady();
        async.flushMicrotasks();
        // Lewati backoff (maksimum 30 detik + jitter 25%).
        async.elapse(const Duration(seconds: 40));
      }
      async.flushMicrotasks();

      expect(statuses, contains(ConnectionStatus.reconnecting));
      expect(statuses, contains(ConnectionStatus.disconnected));
      source.dispose();
    });
  });

  test('pesan allBusLocation diteruskan sebagai daftar Bus', () {
    fakeAsync((async) {
      final fake = _FakeTransport();
      final source = TransWsDataSource(
        transportFactory: (_) => fake,
        random: Random(1),
      );
      final buses = <List<dynamic>>[];
      source.busStream.listen(buses.add);
      async.flushMicrotasks();

      source.connect();
      async.flushMicrotasks();
      fake.completeReady();
      async.flushMicrotasks();
      fake.add(_snapshot());
      async.flushMicrotasks();

      expect(buses, isNotEmpty);
      expect(buses.last.single.number, '65');
      source.dispose();
    });
  });

  test('watchdog menyambung ulang bila socket senyap terlalu lama', () {
    fakeAsync((async) {
      var now = DateTime.utc(2026, 10, 20, 10, 0, 0);
      final transports = <_FakeTransport>[];
      final source = TransWsDataSource(
        transportFactory: (_) {
          final fake = _FakeTransport();
          transports.add(fake);
          return fake;
        },
        now: () => now,
        random: Random(1),
      );
      final statuses = <ConnectionStatus>[];
      source.statusStream.listen(statuses.add);
      async.flushMicrotasks();

      source.connect();
      async.flushMicrotasks();
      transports.last.completeReady();
      async.flushMicrotasks();
      transports.last.add('{"type":"info"}');
      async.flushMicrotasks();

      now = now.add(const Duration(seconds: 31));
      async.elapse(const Duration(seconds: 31));
      async.flushMicrotasks();

      expect(statuses, contains(ConnectionStatus.reconnecting));
      expect(transports.length, greaterThan(1));
      source.dispose();
    });
  });
}
