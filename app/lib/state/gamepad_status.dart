import 'package:flutter/foundation.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/state/poller.dart';

const gamepadStatusInterval = Duration(seconds: 1);

LauncherButtonLayout _alwaysXbox() => LauncherButtonLayout.xbox;

/// Ícone de controle conectado na barra superior e o layout que o modo
/// automático detectou (para as dicas dos botões). As consultas só leem
/// valores mantidos pela thread de leitura do controle (baratas).
class GamepadStatus extends ValueNotifier<bool> {
  GamepadStatus(this._isConnected, {this.detectLayout = _alwaysXbox})
    : super(false);

  final bool Function() _isConnected;
  final LauncherButtonLayout Function() detectLayout;

  /// `xbox` ou `nintendo`: o do último controle usado.
  final detectedLayout = ValueNotifier(LauncherButtonLayout.xbox);

  late final poller = Poller(interval: gamepadStatusInterval, tick: _tick);

  Future<void> _tick() async {
    try {
      value = _isConnected();
      detectedLayout.value = detectLayout();
    } catch (_) {
      // sem ponte ou sem leitura de controles: mostra como desconectado
      value = false;
    }
  }

  @override
  void dispose() {
    poller.dispose();
    detectedLayout.dispose();
    super.dispose();
  }
}
