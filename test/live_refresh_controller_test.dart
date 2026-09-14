import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/live_refresh_controller.dart';
import 'package:silarah/core/cubits/chat/chat_state.dart';

void main() {
  LiveRefreshController controller(
      FakeAsync clock, Future<void> Function() read,
      {int Function(int)? random}) {
    return LiveRefreshController(
      refresh: read,
      now: clock.getClock(DateTime.utc(2026)).now,
      randomInt: random ?? (_) => 0,
    );
  }

  test('a continuous event burst cannot starve catch-up', () {
    fakeAsync((clock) {
      var reads = 0;
      final live = controller(clock, () async {
        reads++;
      })
        ..start();
      live.setConnected(true);
      for (var i = 0; i < 10; i++) {
        live.request();
        clock.elapse(const Duration(milliseconds: 100));
      }
      expect(reads, 1);
      clock.elapse(const Duration(milliseconds: 1400));
      expect(reads, 2);
      live.dispose();
    });
  });

  test('in-flight events queue exactly one trailing read', () {
    fakeAsync((clock) {
      var reads = 0;
      final pending = Completer<void>();
      final live = controller(clock, () {
        reads++;
        return reads == 1 ? pending.future : Future<void>.value();
      })
        ..start();
      live.setConnected(true);
      clock.elapse(const Duration(seconds: 1));
      for (var i = 0; i < 100; i++) {
        live.request();
      }
      clock.elapse(const Duration(seconds: 5));
      expect(reads, 1);
      pending.complete();
      clock.flushMicrotasks();
      clock.elapse(const Duration(milliseconds: 1999));
      expect(reads, 1);
      clock.elapse(const Duration(milliseconds: 1));
      expect(reads, 2);
      clock.elapse(const Duration(minutes: 2));
      expect(reads, 2);
      live.dispose();
    });
  });

  test('healthy sockets do not trigger periodic database polling', () {
    fakeAsync((clock) {
      var reads = 0;
      final live = controller(clock, () async {
        reads++;
      })
        ..start();
      live.setConnected(true);
      clock.elapse(const Duration(hours: 1));
      expect(reads, 1);
      live.dispose();
    });
  });

  test('failed subscriptions get bounded fallback and reconnect catch-up', () {
    fakeAsync((clock) {
      var reads = 0;
      final live = controller(clock, () async {
        reads++;
      })
        ..start();
      clock.elapse(const Duration(seconds: 29));
      expect(reads, 0);
      live.setConnected(false); // Repeated errors must not postpone fallback.
      clock.elapse(const Duration(milliseconds: 1400));
      expect(reads, 1);
      clock.elapse(const Duration(seconds: 30));
      expect(reads, 2);
      live.setConnected(true);
      clock.elapse(const Duration(seconds: 2));
      expect(reads, 3);
      clock.elapse(const Duration(hours: 1));
      expect(reads, 3);
      live.dispose();
    });
  });

  test('jitter stays within 30–45 seconds plus a subsecond read delay', () {
    fakeAsync((clock) {
      var reads = 0;
      final live = controller(clock, () async {
        reads++;
      }, random: (n) => n - 1)
        ..start();
      clock.elapse(const Duration(milliseconds: 45998));
      expect(reads, 0);
      clock.elapse(const Duration(milliseconds: 1));
      expect(reads, 1);
      live.dispose();
    });
  });

  test('pause and disposal cancel timers and late completions', () {
    fakeAsync((clock) {
      var reads = 0;
      final pending = Completer<void>();
      final live = controller(clock, () {
        reads++;
        return pending.future;
      })
        ..start();
      live.request();
      clock.elapse(const Duration(seconds: 1));
      live.request();
      live.stop();
      pending.complete();
      clock.flushMicrotasks();
      clock.elapse(const Duration(minutes: 2));
      expect(reads, 1);
      live.dispose();
      live.start();
      live.setConnected(true);
      live.request();
      clock.elapse(const Duration(minutes: 2));
      expect(reads, 1);
    });
  });

  test('resume restores bounded recovery without polling while paused', () {
    fakeAsync((clock) {
      var reads = 0;
      final live = controller(clock, () async {
        reads++;
      })
        ..start();
      live.stop();
      clock.elapse(const Duration(minutes: 10));
      expect(reads, 0);
      live.start();
      live.request();
      clock.elapse(const Duration(seconds: 1));
      expect(reads, 1);
      live.dispose();
    });
  });

  test('read failures cannot create a tight retry loop', () {
    fakeAsync((clock) {
      var reads = 0;
      final live = controller(clock, () async {
        reads++;
        throw StateError('offline');
      })
        ..start();
      live.request();
      clock.elapse(const Duration(seconds: 29));
      expect(reads, 1);
      clock.elapse(const Duration(seconds: 2));
      expect(reads, 2);
      live.dispose();
    });
  });

  test('failed bubble retains the same operation UUID on retry', () {
    final message = ChatMessage(
      id: 'local-operation',
      operationId: 'operation',
      text: 'Assalamu alaikum',
      sentAt: DateTime.utc(2026),
      isMe: true,
      status: MessageStatus.queued,
    );
    final failed = message.copyWith(status: MessageStatus.failed);
    final retry = failed.copyWith(status: MessageStatus.queued);
    expect(retry.operationId, message.operationId);
    expect(retry.id, message.id);
    expect(retry, message);
  });
}
