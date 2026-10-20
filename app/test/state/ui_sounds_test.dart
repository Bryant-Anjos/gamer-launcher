import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/src/rust/api/sound.dart';
import 'package:gamer_launcher/state/messages.dart';
import 'package:gamer_launcher/state/ui_sounds.dart';

import '../support/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late LauncherMessages messages;
  late List<String> shown;
  var enabled = true;

  setUp(() {
    backend = FakeBackend();
    messages = LauncherMessages();
    shown = [];
    messages.stream.listen(shown.add);
    enabled = true;
  });

  UiSounds sounds() => UiSounds(backend, messages, isEnabled: () => enabled);

  List<String> played() =>
      backend.calls.where((call) => call.startsWith('playUiSound')).toList();

  test('plays the sound when sounds are on', () {
    sounds().play(LauncherSound.confirm);

    expect(played(), ['playUiSound(confirm)']);
  });

  test('stays quiet when sounds are off', () {
    enabled = false;

    sounds().play(LauncherSound.navigate);

    expect(played(), isEmpty);
  });

  test('a failure warns once, not on every move', () async {
    backend.failures['playUiSound'] = 'nenhum programa de áudio';
    final ui = sounds();

    ui
      ..play(LauncherSound.navigate)
      ..play(LauncherSound.navigate);
    await Future<void>.delayed(Duration.zero);

    expect(shown, hasLength(1));
    expect(shown.single, contains('nenhum programa de áudio'));
  });

  test('gamepad actions map to the three sounds', () {
    expect(soundFor(GamepadAction.up), LauncherSound.navigate);
    expect(soundFor(GamepadAction.left), LauncherSound.navigate);
    expect(soundFor(GamepadAction.confirm), LauncherSound.confirm);
    expect(soundFor(GamepadAction.back), LauncherSound.back);
    expect(soundFor(GamepadAction.search), isNull);
    expect(soundFor(GamepadAction.close), isNull);
  });
}
