import 'package:flutter/foundation.dart';
import 'package:gamer_launcher/backend/launcher_backend.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/state/messages.dart';
import 'package:gamer_launcher/state/poller.dart';

/// Cada leitura roda o `bluetoothctl`; o mesmo ritmo do controle rápido.
const bluetoothDevicesInterval = Duration(seconds: 5);

/// Dispositivos pareados: vazio enquanto lê, o erro da última leitura (que
/// vira "Indisponível" na tela) e os que estão conectando/desconectando.
@immutable
class BluetoothDevicesState {
  const BluetoothDevicesState({this.devices, this.error, this.busy = const {}});

  final List<PairedDevice>? devices;
  final String? error;
  final Set<String> busy;

  bool isBusy(String address) => busy.contains(address);

  BluetoothDevicesState withDevices(List<PairedDevice> next) =>
      BluetoothDevicesState(devices: next, busy: busy);

  BluetoothDevicesState withError(String message) =>
      BluetoothDevicesState(devices: devices, error: message, busy: busy);

  BluetoothDevicesState withBusy(String address, {required bool busy}) =>
      BluetoothDevicesState(
        devices: devices,
        error: error,
        busy: busy
            ? {...this.busy, address}
            : this.busy.where((a) => a != address).toSet(),
      );
}

/// Lista dos pareados no controle rápido, com conectar/desconectar. Lida só
/// com o painel na tela. Uma leitura que falha não avisa (ela se repete a
/// cada 5 s); conectar que falha avisa com o nome do dispositivo.
class BluetoothDevicesController extends ValueNotifier<BluetoothDevicesState> {
  BluetoothDevicesController(this._backend, this._messages)
    : super(const BluetoothDevicesState());

  final LauncherBackend _backend;
  final LauncherMessages _messages;
  bool _disposed = false;

  late final poller = Poller(interval: bluetoothDevicesInterval, tick: refresh);

  @override
  set value(BluetoothDevicesState next) {
    if (!_disposed) super.value = next;
  }

  Future<void> refresh() async {
    try {
      value = value.withDevices(await _backend.listPairedDevices());
    } on BackendException catch (error) {
      value = value.withError(error.message);
    }
  }

  /// Conecta o desconectado e desconecta o conectado. Apertar de novo
  /// enquanto conecta (pode levar até 15 s) não faz nada.
  Future<void> toggle(PairedDevice device) async {
    final address = device.address;
    if (value.isBusy(address)) return;
    value = value.withBusy(address, busy: true);
    try {
      await (device.connected
          ? _backend.disconnectBluetoothDevice(address)
          : _backend.connectBluetoothDevice(address));
    } on BackendException catch (error) {
      final what = device.connected ? 'desconectar' : 'conectar';
      _messages.show('Não foi possível $what ${device.name}: ${error.message}');
    } finally {
      value = value.withBusy(address, busy: false);
    }
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    poller.dispose();
    super.dispose();
  }
}
