import 'package:flutter/foundation.dart';
import 'package:gamer_launcher/backend/launcher_backend.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/state/latest_writer.dart';
import 'package:gamer_launcher/state/messages.dart';
import 'package:gamer_launcher/state/poller.dart';
import 'package:gamer_launcher/state/quick_controls_edit.dart';

/// Cada leitura roda vários programas (nmcli, bluetoothctl, wpctl), por
/// isso é bem mais espaçada que a dos gráficos de sistema.
const quickControlsInterval = Duration(seconds: 5);
const _minPercent = 0;
const _maxPercent = 100;

/// Estado do painel de controle rápido e dos ícones da barra superior.
/// Mudanças aparecem na hora (otimistas); se o sistema recusar, um aviso
/// aparece e a tela volta ao estado real.
class QuickControlsController extends ValueNotifier<QuickControls?> {
  QuickControlsController(this._backend, this._messages) : super(null);

  final LauncherBackend _backend;
  final LauncherMessages _messages;
  int _writesInFlight = 0;

  /// Sobe a cada mudança pedida; leitura iniciada antes dela é velha.
  int _generation = 0;
  bool _disposed = false;

  late final poller = Poller(
    interval: quickControlsInterval,
    tick: refresh,
    onError: (error) => _messages.show('Falha ao ler o sistema: $error'),
  );

  late final _volume = LatestWriter(
    (percent) => _write('o volume', () => _backend.setVolumePercent(percent)),
  );
  late final _brightness = LatestWriter(
    (percent) =>
        _write('o brilho', () => _backend.setBrightnessPercent(percent)),
  );

  /// Lê o sistema; uma leitura durante uma mudança é descartada para não
  /// desfazer na tela o que o usuário acabou de pedir.
  Future<void> refresh() async {
    if (_writesInFlight > 0) return;
    final generation = _generation;
    final reading = await _backend.readQuickControls();
    final isCurrent = generation == _generation && _writesInFlight == 0;
    if (isCurrent && !_disposed) value = reading;
  }

  /// Releitura depois de uma recusa: falha vira aviso, nunca exceção solta.
  Future<void> _reread() async {
    try {
      await refresh();
    } on BackendException catch (error) {
      _messages.show('Falha ao ler o sistema: ${error.message}');
    }
  }

  Future<void> _write(String what, Future<void> Function() call) async {
    _writesInFlight++;
    var failed = false;
    try {
      await call();
    } on BackendException catch (error) {
      failed = true;
      _messages.show('Não foi possível alterar $what: ${error.message}');
    } finally {
      _writesInFlight--;
    }
    if (failed) await _reread();
  }

  Future<void> _change(
    QuickControls Function(QuickControls current) apply,
    Future<void> Function() send,
  ) async {
    final current = value;
    if (current == null || _disposed) return;
    _generation++;
    value = apply(current);
    await send();
  }

  Future<void> setWifi(bool enabled) => _change(
    (c) => c.copyWith(wifi: toggleTo(enabled)),
    () => _write('o Wi-Fi', () => _backend.setWifiEnabled(enabled)),
  );

  Future<void> setBluetooth(bool enabled) => _change(
    (c) => c.copyWith(bluetooth: toggleTo(enabled)),
    () => _write('o Bluetooth', () => _backend.setBluetoothEnabled(enabled)),
  );

  Future<void> setDarkMode(bool dark) => _change(
    (c) => c.copyWith(darkMode: toggleTo(dark)),
    () => _write('o modo escuro', () => _backend.setSystemDarkMode(dark)),
  );

  Future<void> setVolume(int percent) {
    final clamped = percent.clamp(_minPercent, _maxPercent);
    return _change(
      (c) => c.copyWith(volume: levelTo(c.volume, clamped)),
      () => _volume.submit(clamped),
    );
  }

  Future<void> setBrightness(int percent) {
    final clamped = percent.clamp(_minPercent, _maxPercent);
    return _change(
      (c) => c.copyWith(brightness: levelTo(c.brightness, clamped)),
      () => _brightness.submit(clamped),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    poller.dispose();
    super.dispose();
  }
}
