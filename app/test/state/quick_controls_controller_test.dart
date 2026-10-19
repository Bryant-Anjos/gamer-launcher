import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/state/messages.dart';
import 'package:gamer_launcher/state/quick_controls_controller.dart';

import '../support/fake_backend.dart';
import '../support/samples.dart';

class _Setup {
  _Setup() {
    messages.stream.listen(shown.add);
  }

  final backend = FakeBackend();
  final messages = LauncherMessages();
  final shown = <String>[];
  late final controller = QuickControlsController(backend, messages);

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

const _offline = QuickControls(
  wifi: ToggleReading(enabled: false),
  bluetooth: ToggleReading(error: 'indisponível: sem adaptador bluetooth'),
  darkMode: ToggleReading(enabled: false),
  volume: LevelReading(percent: 30, muted: true),
  brightness: LevelReading(muted: false, error: 'sem controle de brilho'),
);

void main() {
  test('starts empty and reads the system on refresh', () async {
    final s = _Setup();
    expect(s.controller.value, isNull);

    await s.controller.refresh();

    expect(s.controller.value, sampleQuickControls);
  });

  test(
    'turning wifi off updates the panel at once and asks the system',
    () async {
      final s = _Setup();
      await s.controller.refresh();

      final done = s.controller.setWifi(false);
      expect(s.controller.value!.wifi.enabled, isFalse);
      await done;

      expect(s.backend.calls, contains('setWifiEnabled(false)'));
    },
  );

  test('bluetooth and system dark mode go to their own commands', () async {
    final s = _Setup();
    await s.controller.refresh();

    await s.controller.setBluetooth(false);
    await s.controller.setDarkMode(false);

    expect(s.controller.value!.bluetooth.enabled, isFalse);
    expect(s.controller.value!.darkMode.enabled, isFalse);
    expect(
      s.backend.calls,
      containsAll(['setBluetoothEnabled(false)', 'setSystemDarkMode(false)']),
    );
  });

  test(
    'a refused change shows a message and goes back to the real state',
    () async {
      final s = _Setup();
      await s.controller.refresh();
      s.backend.failures['setBluetoothEnabled'] = 'bluetoothctl falhou';

      await s.controller.setBluetooth(false);
      await s.settle();

      expect(
        s.shown.single,
        'Não foi possível alterar o Bluetooth: bluetoothctl falhou',
      );
      expect(s.controller.value!.bluetooth.enabled, isTrue);
    },
  );

  test('levels are clamped to 0..100', () async {
    final s = _Setup();
    await s.controller.refresh();

    await s.controller.setVolume(130);
    await s.controller.setBrightness(-5);

    expect(s.controller.value!.volume.percent, 100);
    expect(s.controller.value!.brightness.percent, 0);
    expect(
      s.backend.calls,
      containsAll(['setVolumePercent(100)', 'setBrightnessPercent(0)']),
    );
  });

  test('quick level changes are merged so only the last one waits', () async {
    final s = _Setup();
    await s.controller.refresh();
    final gate = Completer<void>();
    s.backend.gates['setVolumePercent'] = gate;

    final first = s.controller.setVolume(85);
    unawaited(s.controller.setVolume(90));
    final last = s.controller.setVolume(95);
    await s.settle();
    gate.complete();
    await Future.wait([first, last]);
    await s.settle();

    final volumeCalls = s.backend.calls
        .where((call) => call.startsWith('setVolumePercent'))
        .toList();
    expect(volumeCalls, ['setVolumePercent(85)', 'setVolumePercent(95)']);
    expect(s.controller.value!.volume.percent, 95);
  });

  test('a poll that lands during a change does not undo it', () async {
    final s = _Setup();
    await s.controller.refresh();
    final gate = Completer<void>();
    s.backend.gates['setWifiEnabled'] = gate;

    final change = s.controller.setWifi(false);
    await s.controller.refresh();
    expect(s.controller.value!.wifi.enabled, isFalse);

    gate.complete();
    await change;
  });

  test('changes before the first reading are ignored safely', () async {
    final s = _Setup();

    await s.controller.setWifi(true);
    await s.controller.setVolume(50);

    expect(s.backend.calls, isNot(contains('setWifiEnabled(true)')));
    expect(s.controller.value, isNull);
  });

  test('unavailable controls keep their error', () async {
    final s = _Setup();
    s.backend.quickControls = _offline;

    await s.controller.refresh();

    expect(s.controller.value!.bluetooth.error, contains('sem adaptador'));
    expect(s.controller.value!.brightness.percent, isNull);
    expect(s.controller.value!.volume.muted, isTrue);
  });

  test('the poller reads the system while attached', () async {
    final s = _Setup();

    s.controller.poller.attach();
    await s.settle();
    s.controller.poller.detach();

    expect(s.controller.value, sampleQuickControls);
    s.controller.dispose();
  });

  test(
    'a poll that started before a finished change does not undo it',
    () async {
      final s = _Setup();
      await s.controller.refresh();
      final gate = Completer<void>();
      s.backend.gates['readQuickControls'] = gate;

      final poll = s.controller.refresh();
      await s.controller.setWifi(false);
      gate.complete();
      await poll;

      expect(s.controller.value!.wifi.enabled, isFalse);
    },
  );

  test(
    'a failed re-read after a refused change is reported, not thrown',
    () async {
      final s = _Setup();
      await s.controller.refresh();
      s.backend.failures['setVolumePercent'] = 'wpctl falhou';
      s.backend.failures['readQuickControls'] = 'nmcli falhou';

      await s.controller.setVolume(40);
      await s.settle();

      expect(s.shown, hasLength(2));
      expect(s.shown.last, contains('nmcli falhou'));
    },
  );
}
