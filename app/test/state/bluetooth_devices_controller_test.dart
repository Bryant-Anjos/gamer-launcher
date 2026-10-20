import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/state/bluetooth_devices_controller.dart';
import 'package:gamer_launcher/state/messages.dart';

import '../support/fake_backend.dart';

const _headset = PairedDevice(
  address: 'AA:BB:CC:DD:EE:01',
  name: 'Fone',
  connected: false,
);
const _pad = PairedDevice(
  address: 'AA:BB:CC:DD:EE:02',
  name: 'Pro Controller',
  connected: true,
);

class _Setup {
  _Setup() {
    messages.stream.listen(shown.add);
  }

  final backend = FakeBackend(pairedDevices: const [_pad, _headset]);
  final messages = LauncherMessages();
  final shown = <String>[];
  late final controller = BluetoothDevicesController(backend, messages);

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  test('starts reading and then lists the paired devices', () async {
    final s = _Setup();
    expect(s.controller.value.devices, isNull);

    await s.controller.refresh();

    expect(s.controller.value.devices, [_pad, _headset]);
    expect(s.controller.value.error, isNull);
  });

  test('a failed read shows as unavailable, without a message', () async {
    final s = _Setup();
    s.backend.failures['listPairedDevices'] = 'bluetoothctl não encontrado';

    await s.controller.refresh();
    await s.settle();

    expect(s.controller.value.error, 'bluetoothctl não encontrado');
    expect(s.shown, isEmpty);
  });

  test('toggling a disconnected device connects it and reads again', () async {
    final s = _Setup();
    await s.controller.refresh();
    s.backend.calls.clear();

    await s.controller.toggle(_headset);

    expect(s.backend.calls, [
      'connectBluetoothDevice(${_headset.address})',
      'listPairedDevices',
    ]);
  });

  test('toggling a connected device disconnects it', () async {
    final s = _Setup();

    await s.controller.toggle(_pad);

    expect(s.backend.calls.first, 'disconnectBluetoothDevice(${_pad.address})');
  });

  test('the device is busy while connecting and repeats are ignored', () async {
    final s = _Setup();
    await s.controller.refresh();
    final gate = Completer<void>();
    s.backend.gates['connectBluetoothDevice'] = gate;

    final first = s.controller.toggle(_headset);
    await s.settle();
    expect(s.controller.value.isBusy(_headset.address), isTrue);
    unawaited(s.controller.toggle(_headset));

    gate.complete();
    await first;
    expect(s.controller.value.isBusy(_headset.address), isFalse);
    expect(
      s.backend.calls.where((c) => c.startsWith('connectBluetoothDevice')),
      hasLength(1),
    );
  });

  test('a refused connection says which device and why', () async {
    final s = _Setup();
    s.backend.failures['connectBluetoothDevice'] =
        'o dispositivo não respondeu';

    await s.controller.toggle(_headset);
    await s.settle();

    expect(s.shown.single, contains('Fone'));
    expect(s.shown.single, contains('o dispositivo não respondeu'));
    expect(s.controller.value.isBusy(_headset.address), isFalse);
  });
}
