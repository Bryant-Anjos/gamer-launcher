import 'package:flutter/foundation.dart';
import 'package:gamer_launcher/backend/launcher_backend.dart';
import 'package:gamer_launcher/state/messages.dart';

/// Iniciar com o sistema. Vazio até a primeira leitura. A verdade é o
/// arquivo em `~/.config/autostart`, lido pelo núcleo; a mudança aparece na
/// hora e volta ao estado real se o sistema recusar.
class AutostartController extends ValueNotifier<bool?> {
  AutostartController(this._backend, this._messages) : super(null);

  final LauncherBackend _backend;
  final LauncherMessages _messages;
  bool _disposed = false;

  @override
  set value(bool? next) {
    if (!_disposed) super.value = next;
  }

  Future<void> load() async {
    try {
      value = await _backend.autostartEnabled();
    } on BackendException catch (error) {
      _messages.show(
        'Não foi possível ler "iniciar com o sistema": ${error.message}',
      );
    }
  }

  Future<void> set(bool enabled) async {
    final previous = value;
    value = enabled;
    try {
      await _backend.setAutostart(enabled);
    } on BackendException catch (error) {
      value = previous ?? !enabled;
      _messages.show(
        'Não foi possível mudar "iniciar com o sistema": ${error.message}',
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
