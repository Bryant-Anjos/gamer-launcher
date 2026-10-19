import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/state/poller.dart';

const _interval = Duration(seconds: 1);

void main() {
  test('does nothing until someone attaches', () {
    fakeAsync((async) {
      var ticks = 0;
      Poller(interval: _interval, tick: () async => ticks++);

      async.elapse(const Duration(seconds: 5));

      expect(ticks, 0);
    });
  });

  test('ticks right away and then on every interval while attached', () {
    fakeAsync((async) {
      var ticks = 0;
      final poller = Poller(interval: _interval, tick: () async => ticks++);

      poller.attach();
      async.flushMicrotasks();
      expect(ticks, 1);

      async.elapse(const Duration(seconds: 3));
      expect(ticks, 4);

      poller.detach();
      async.elapse(const Duration(seconds: 3));
      expect(ticks, 4);
    });
  });

  test('keeps running until the last client detaches', () {
    fakeAsync((async) {
      var ticks = 0;
      final poller = Poller(interval: _interval, tick: () async => ticks++)
        ..attach()
        ..attach();

      poller.detach();
      async.elapse(const Duration(seconds: 2));

      expect(ticks, 3);
      expect(poller.isRunning, isTrue);
      poller.detach();
      expect(poller.isRunning, isFalse);
    });
  });

  test('pauses while the launcher is not visible', () {
    fakeAsync((async) {
      var ticks = 0;
      final poller = Poller(interval: _interval, tick: () async => ticks++)
        ..attach();
      async.flushMicrotasks();

      poller.visible = false;
      async.elapse(const Duration(seconds: 5));
      expect(ticks, 1);

      poller.visible = true;
      async.flushMicrotasks();
      expect(ticks, 2, reason: 'ao voltar a ficar visível lê na hora');
    });
  });

  test('a slow tick is not started again while it runs', () {
    fakeAsync((async) {
      var started = 0;
      final pending = Completer<void>();
      final poller = Poller(
        interval: _interval,
        tick: () {
          started++;
          return pending.future;
        },
      )..attach();

      async.elapse(const Duration(seconds: 3));
      expect(started, 1);

      pending.complete();
      async.elapse(_interval);
      expect(started, 2);
      poller.detach();
    });
  });

  test('a failing tick does not stop the polling', () {
    fakeAsync((async) {
      var ticks = 0;
      final errors = <Object>[];
      final poller = Poller(
        interval: _interval,
        tick: () async {
          ticks++;
          throw StateError('falhou');
        },
        onError: errors.add,
      )..attach();

      async.elapse(const Duration(seconds: 2));

      expect(ticks, 3);
      expect(errors, hasLength(3));
      poller.detach();
    });
  });

  test('detaching more than attaching is harmless', () {
    final poller = Poller(interval: _interval, tick: () async {});

    poller.detach();

    expect(poller.isRunning, isFalse);
  });
}
