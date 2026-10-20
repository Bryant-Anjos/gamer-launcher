import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/state/messages.dart';
import 'package:gamer_launcher/state/power_controller.dart';

import '../support/fake_backend.dart';

class _Setup {
  _Setup({FakeBackend? backend}) : backend = backend ?? FakeBackend() {
    messages.stream.listen(shown.add);
  }

  final FakeBackend backend;
  final messages = LauncherMessages();
  final shown = <String>[];
  late final controller = PowerController(backend, messages);

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  test('starts without a reading and reads the battery on refresh', () async {
    final s = _Setup();
    expect(s.controller.value, isNull);

    await s.controller.refresh();

    expect(
      s.controller.value,
      const BatteryReading(percent: 80, charging: false),
    );
  });

  test('a computer without battery stays empty', () async {
    final s = _Setup(backend: FakeBackend(battery: null));

    await s.controller.refresh();

    expect(s.controller.value, isNull);
  });

  test(
    'a failed battery read keeps the last value and does not warn',
    () async {
      final s = _Setup();
      await s.controller.refresh();
      s.backend.failures['readBattery'] = 'sem leitura';

      await s.controller.refresh();
      await s.settle();

      expect(s.controller.value?.percent, 80);
      expect(s.shown, isEmpty, reason: 'a bateria é só um indicador');
    },
  );

  test('power actions go to the system', () async {
    final s = _Setup();

    for (final action in PowerAction.values) {
      await s.controller.perform(action);
    }

    expect(s.backend.calls, [
      'performPowerAction(shutdown)',
      'performPowerAction(reboot)',
      'performPowerAction(suspend)',
      'performPowerAction(logOut)',
    ]);
  });

  test('a refused power action becomes a message, not an exception', () async {
    final s = _Setup();
    s.backend.failures['performPowerAction'] = 'sem permissão';

    await s.controller.perform(PowerAction.shutdown);
    await s.settle();

    expect(s.shown.single, contains('sem permissão'));
    expect(s.shown.single, contains('desligar'));
  });
}
