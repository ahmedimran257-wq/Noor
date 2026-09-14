import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exercises the pinned production SDK with real loopback WebSockets, not a
/// mocked channel counter. Never contacts Supabase or consumes project quota.
class _LocalRealtimeServer {
  _LocalRealtimeServer(this.server);

  final HttpServer server;
  final Set<WebSocket> sockets = {};
  bool acknowledgeLeaves = true;
  int maximumSockets = 0;
  int repliesSkippedAfterClose = 0;

  void reply(WebSocket socket, Map<String, dynamic> message) {
    // A peer may close immediately after sending leave, before this queued
    // event is handled. A real server cannot ACK a closed transport either.
    // Keep join timeouts and socket-cleanup assertions unchanged: this only
    // prevents the fixture itself from throwing on an already-closed sink.
    if (socket.readyState != WebSocket.open) {
      repliesSkippedAfterClose++;
      return;
    }
    socket.add(jsonEncode({
      'topic': message['topic'],
      'event': 'phx_reply',
      'ref': message['ref'],
      'payload': {
        'status': 'ok',
        'response': <String, dynamic>{},
      },
    }));
  }

  static Future<_LocalRealtimeServer> start() async {
    final instance = _LocalRealtimeServer(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    instance.server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      instance.sockets.add(socket);
      if (instance.sockets.length > instance.maximumSockets) {
        instance.maximumSockets = instance.sockets.length;
      }
      socket.listen((data) {
        final message = jsonDecode(data as String) as Map<String, dynamic>;
        if (message['event'] == 'phx_leave' && !instance.acknowledgeLeaves) {
          return;
        }
        if (['phx_join', 'phx_leave', 'heartbeat'].contains(message['event'])) {
          instance.reply(socket, message);
        }
      }, onDone: () => instance.sockets.remove(socket));
    });
    return instance;
  }

  RealtimeClient client() => RealtimeClient(
        'ws://127.0.0.1:${server.port}/realtime/v1',
        timeout: const Duration(milliseconds: 400),
      );

  Future<void> close() async {
    await Future.wait(sockets.toList().map((socket) => socket.close()));
    await server.close(force: true);
  }
}

Future<void> _waitUntil(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Socket/channel state failed to settle within 5 seconds');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<RealtimeChannel> _join(RealtimeClient client, String topic) async {
  final ready = Completer<void>();
  final channel = client.channel(topic).subscribe((status, error) {
    if (!ready.isCompleted && status == RealtimeSubscribeStatus.subscribed) {
      ready.complete();
    }
  });
  await ready.future.timeout(const Duration(seconds: 5));
  return channel;
}

void main() {
  test('fixture safely drops an acknowledgement after its peer has closed',
      () async {
    final server = await _LocalRealtimeServer.start();
    final peer = await WebSocket.connect(
      'ws://127.0.0.1:${server.server.port}/realtime/v1',
    );
    // Drain the client stream so the close handshake can complete.
    final subscription = peer.listen((_) {});
    try {
      await _waitUntil(() => server.sockets.length == 1);
      final closedSocket = server.sockets.single;
      await peer.close();
      await _waitUntil(() => server.sockets.isEmpty);
      expect(closedSocket.readyState, WebSocket.closed);
      server.reply(closedSocket, {'topic': 'audit', 'ref': '1'});
      expect(server.repliesSkippedAfterClose, 1);
    } finally {
      await subscription.cancel();
      await peer.close();
      await server.close();
    }
  });

  test('40 open/leave cycles release the final SDK channel and actual socket',
      () async {
    final server = await _LocalRealtimeServer.start();
    final client = server.client();
    try {
      for (var cycle = 0; cycle < 40; cycle++) {
        final channel = await _join(client, 'audit-$cycle');
        expect(client.getChannels(), hasLength(1));
        expect(server.sockets, hasLength(1));
        await client.removeChannel(channel);
        await _waitUntil(() => server.sockets.isEmpty && !client.isConnected);
        expect(client.getChannels(), isEmpty);
      }
      expect(server.maximumSockets, 1);
    } finally {
      await client.removeAllChannels();
      await server.close();
    }
  });

  test('removing one screen preserves another active screen on one socket',
      () async {
    final server = await _LocalRealtimeServer.start();
    final client = server.client();
    try {
      final chat = await _join(client, 'chat');
      final photos = await _join(client, 'photos');
      expect(server.sockets, hasLength(1));
      await client.removeChannel(chat);
      expect(client.getChannels(), [photos]);
      expect(client.isConnected, isTrue);
      await client.removeChannel(photos);
      await _waitUntil(() => server.sockets.isEmpty && !client.isConnected);
      expect(client.getChannels(), isEmpty);
    } finally {
      await client.removeAllChannels();
      await server.close();
    }
  });

  test('missing leave acknowledgement does not prevent transport cleanup',
      () async {
    final server = await _LocalRealtimeServer.start();
    final client = server.client();
    try {
      final channel = await _join(client, 'lost-leave');
      server.acknowledgeLeaves = false;
      // This pinned SDK locally acknowledges unsubscribe after marking the
      // channel leaving; a missing server ACK must not retain the socket.
      expect(await client.removeChannel(channel), 'ok');
      await _waitUntil(() => server.sockets.isEmpty && !client.isConnected);
      expect(client.getChannels(), isEmpty);
    } finally {
      await client.removeAllChannels();
      await server.close();
    }
  });
}
