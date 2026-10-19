import 'package:flutter/foundation.dart';
import 'package:gamer_launcher/state/poller.dart';

const gamepadStatusInterval = Duration(seconds: 1);

/// Ícone de controle conectado na barra superior. A consulta só lê um
/// contador mantido pela thread de leitura do controle (barata).
class GamepadStatus extends ValueNotifier<bool> {
  GamepadStatus(this._isConnected) : super(false);

  final bool Function() _isConnected;

  late final poller = Poller(interval: gamepadStatusInterval, tick: _tick);

  Future<void> _tick() async {
    try {
      value = _isConnected();
    } catch (_) {
      // sem ponte ou sem leitura de controles: mostra como desconectado
      value = false;
    }
  }

  @override
  void dispose() {
    poller.dispose();
    super.dispose();
  }
}
