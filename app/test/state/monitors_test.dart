import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/state/clock.dart';
import 'package:gamer_launcher/state/gamepad_status.dart';
import 'package:gamer_launcher/state/system_monitor.dart';

StatsSample _sample(double cpu) => StatsSample(
  cpuPercent: cpu,
  ramUsedBytes: 4e9,
  ramTotalBytes: 16e9,
  diskUsedBytes: 100e9,
  diskTotalBytes: 400e9,
);

void main() {
  group('SystemHistory', () {
    test('keeps percentages of every resource', () {
      final history = const SystemHistory().add(_sample(12), 3);

      expect(history.latest!.cpuPercent, 12);
      expect(history.cpu, [12]);
      expect(history.ram, [25]);
      expect(history.disk, [25]);
    });

    test('drops the oldest values past the limit', () {
      var history = const SystemHistory();
      for (final cpu in [1.0, 2.0, 3.0, 4.0]) {
        history = history.add(_sample(cpu), 3);
      }

      expect(history.cpu, [2, 3, 4]);
    });

    test('totals of zero count as zero percent', () {
      const empty = StatsSample(
        cpuPercent: 0,
        ramUsedBytes: 0,
        ramTotalBytes: 0,
        diskUsedBytes: 0,
        diskTotalBytes: 0,
      );

      expect(const SystemHistory().add(empty, 3).ram, [0]);
    });
  });

  test('the monitor samples once per second while attached', () {
    fakeAsync((async) {
      var cpu = 0.0;
      final monitor = SystemMonitor(() async => _sample(cpu += 10));

      monitor.poller.attach();
      async.elapse(const Duration(seconds: 2));
      monitor.poller.detach();
      async.elapse(const Duration(seconds: 5));

      expect(monitor.value.cpu, [10, 20, 30]);
      monitor.dispose();
    });
  });

  test('gamepad status also follows the detected button layout', () {
    fakeAsync((async) {
      var detected = LauncherButtonLayout.xbox;
      final status = GamepadStatus(
        () => true,
        detectLayout: () => detected,
      );

      status.poller.attach();
      async.flushMicrotasks();
      expect(status.detectedLayout.value, LauncherButtonLayout.xbox);

      detected = LauncherButtonLayout.nintendo;
      async.elapse(const Duration(seconds: 1));
      expect(status.detectedLayout.value, LauncherButtonLayout.nintendo);
      status.dispose();
    });
  });

  test('gamepad status follows the core', () {
    fakeAsync((async) {
      var connected = false;
      final status = GamepadStatus(() => connected);

      status.poller.attach();
      async.flushMicrotasks();
      expect(status.value, isFalse);

      connected = true;
      async.elapse(const Duration(seconds: 1));
      expect(status.value, isTrue);
      status.dispose();
    });
  });

  test('a failing gamepad check counts as not connected', () {
    fakeAsync((async) {
      final status = GamepadStatus(() => throw StateError('sem ponte'));

      status.poller.attach();
      async.flushMicrotasks();

      expect(status.value, isFalse);
      status.dispose();
    });
  });

  test('the clock ticks on each new minute', () {
    fakeAsync((async) {
      final start = DateTime(2026, 10, 19, 19, 41, 50);
      final clock = Clock(now: () => start.add(async.elapsed));

      expect(clock.value.minute, 41);
      async.elapse(const Duration(seconds: 10));
      expect(clock.value.minute, 42);
      async.elapse(const Duration(minutes: 1));
      expect(clock.value.minute, 43);
      clock.dispose();
    });
  });

  test('a failing monitor warns once and keeps trying', () {
    fakeAsync((async) {
      final shown = <String>[];
      var calls = 0;
      final monitor = SystemMonitor(() async {
        calls++;
        throw StateError('sysinfo');
      }, onError: shown.add);

      monitor.poller.attach();
      async.elapse(const Duration(seconds: 3));

      expect(calls, 4);
      expect(shown.single, contains('sysinfo'));
      monitor.dispose();
    });
  });
}
