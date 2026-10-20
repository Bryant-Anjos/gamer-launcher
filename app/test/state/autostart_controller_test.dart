import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/state/autostart_controller.dart';
import 'package:gamer_launcher/state/messages.dart';

import '../support/fake_backend.dart';

class _Setup {
  _Setup({bool enabled = false}) : backend = FakeBackend(autostart: enabled) {
    messages.stream.listen(shown.add);
  }

  final FakeBackend backend;
  final messages = LauncherMessages();
  final shown = <String>[];
  late final controller = AutostartController(backend, messages);

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  test('is unknown until loaded, then follows the system', () async {
    final s = _Setup(enabled: true);
    expect(s.controller.value, isNull);

    await s.controller.load();

    expect(s.controller.value, isTrue);
  });

  test('turning it on shows at once and asks the system', () async {
    final s = _Setup();
    await s.controller.load();

    final done = s.controller.set(true);
    expect(s.controller.value, isTrue);
    await done;

    expect(s.backend.calls, contains('setAutostart(true)'));
    expect(s.backend.autostart, isTrue);
  });

  test('a refusal goes back to the real state and warns', () async {
    final s = _Setup();
    await s.controller.load();
    s.backend.failures['setAutostart'] = 'sem pasta de configuração';

    await s.controller.set(true);
    await s.settle();

    expect(s.controller.value, isFalse);
    expect(s.shown.single, contains('sem pasta de configuração'));
  });

  test('a failed load warns and leaves it unknown', () async {
    final s = _Setup();
    s.backend.failures['autostartEnabled'] = 'ilegível';

    await s.controller.load();
    await s.settle();

    expect(s.controller.value, isNull);
    expect(s.shown, hasLength(1));
  });
}
