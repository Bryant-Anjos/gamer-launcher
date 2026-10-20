import 'package:flutter/foundation.dart';
import 'package:gamer_launcher/backend/launcher_backend.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/state/messages.dart';
import 'package:gamer_launcher/state/poller.dart';

/// A bateria muda devagar; uma leitura a cada 30 s basta.
const batteryInterval = Duration(seconds: 30);

String _what(PowerAction action) => switch (action) {
  PowerAction.shutdown => 'desligar',
  PowerAction.reboot => 'reiniciar',
  PowerAction.suspend => 'suspender',
  PowerAction.logOut => 'encerrar a sessão',
};

/// Bateria do computador (vazia quando não há ou não foi possível ler) e
/// as ações de energia. A bateria é só um indicador: leitura que falha
/// mantém o último valor, sem aviso. Ação de energia que falha avisa.
class PowerController extends ValueNotifier<BatteryReading?> {
  PowerController(this._backend, this._messages) : super(null);

  final LauncherBackend _backend;
  final LauncherMessages _messages;
  bool _disposed = false;

  late final poller = Poller(interval: batteryInterval, tick: refresh);

  Future<void> refresh() async {
    try {
      final reading = await _backend.readBattery();
      if (!_disposed) value = reading;
    } on BackendException {
      // mantém o último valor
    }
  }

  Future<void> perform(PowerAction action) async {
    try {
      await _backend.performPowerAction(action);
    } on BackendException catch (error) {
      _messages.show('Não foi possível ${_what(action)}: ${error.message}');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    poller.dispose();
    super.dispose();
  }
}
