import 'package:gamer_launcher/backend/launcher_backend.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/src/rust/api/sound.dart';
import 'package:gamer_launcher/state/messages.dart';

/// Som de cada ação do controle; as outras ficam em silêncio.
LauncherSound? soundFor(GamepadAction action) => switch (action) {
  GamepadAction.up ||
  GamepadAction.down ||
  GamepadAction.left ||
  GamepadAction.right => LauncherSound.navigate,
  GamepadAction.confirm => LauncherSound.confirm,
  GamepadAction.back => LauncherSound.back,
  _ => null,
};

/// Sons opcionais da interface (navegar, confirmar, voltar). Tocam só com a
/// opção ligada; uma falha (sem programa de áudio) avisa uma vez, para não
/// repetir o aviso a cada movimento.
class UiSounds {
  UiSounds(this._backend, this._messages, {required this.isEnabled});

  final LauncherBackend _backend;
  final LauncherMessages _messages;
  final bool Function() isEnabled;
  bool _warned = false;

  void play(LauncherSound sound) {
    if (!isEnabled()) return;
    try {
      _backend.playUiSound(sound);
    } on BackendException catch (error) {
      if (_warned) return;
      _warned = true;
      _messages.show('Não foi possível tocar os sons: ${error.message}');
    }
  }
}
