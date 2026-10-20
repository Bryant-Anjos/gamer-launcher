import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/ui/quick/bluetooth_devices.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';
import '../support/samples.dart';

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

FakeBackend _backend({
  List<PairedDevice> devices = const [_pad, _headset],
  bool bluetoothOn = true,
}) => FakeBackend(
  pairedDevices: devices,
  quickControls: QuickControls(
    wifi: sampleQuickControls.wifi,
    wifiName: sampleQuickControls.wifiName,
    bluetooth: ToggleReading(enabled: bluetoothOn),
    darkMode: sampleQuickControls.darkMode,
    volume: sampleQuickControls.volume,
    brightness: sampleQuickControls.brightness,
  ),
);

Future<LauncherHarness> _openQuick(
  WidgetTester tester,
  FakeBackend backend,
) async {
  final h = await pumpLauncher(tester, backend: backend);
  await h.pressAndSettle(tester, GamepadAction.quickControls);
  return h;
}

int _reads(FakeBackend backend) =>
    backend.calls.where((call) => call == 'listPairedDevices').length;

void main() {
  testWidgets('the overlay lists the paired devices and their state', (
    tester,
  ) async {
    await _openQuick(tester, _backend());

    expect(find.byType(BluetoothDevicesSection), findsOneWidget);
    expect(find.text('Pro Controller'), findsOneWidget);
    expect(find.text('Conectado'), findsOneWidget);
    expect(find.text('Fone'), findsOneWidget);
    expect(find.text('Desconectado'), findsOneWidget);
  });

  testWidgets('A on a device connects it', (tester) async {
    final backend = _backend();
    await _openQuick(tester, backend);

    await tester.tap(find.text('Fone'));
    await tester.pumpAndSettle();

    expect(
      backend.calls,
      contains('connectBluetoothDevice(${_headset.address})'),
    );
  });

  testWidgets('with bluetooth off the list asks to turn it on', (tester) async {
    await _openQuick(tester, _backend(bluetoothOn: false));

    expect(find.text(bluetoothOffText), findsOneWidget);
    expect(find.text('Fone'), findsNothing);
  });

  testWidgets('without paired devices it says how to pair', (tester) async {
    await _openQuick(tester, _backend(devices: const []));

    expect(find.text(noPairedDevicesText), findsOneWidget);
  });

  testWidgets('the shortcuts open the system bluetooth and network pages', (
    tester,
  ) async {
    final backend = _backend();
    await _openQuick(tester, backend);

    await tester.tap(find.text('Configurações de Bluetooth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configurações de rede'));
    await tester.pumpAndSettle();

    expect(backend.calls, contains('openSettingsPage(bluetooth)'));
    expect(backend.calls, contains('openSettingsPage(wireless)'));
  });

  testWidgets('a settings page that does not open becomes a message', (
    tester,
  ) async {
    final backend = _backend()
      ..failures['openSettingsPage'] = 'cosmic-settings não encontrado';
    await _openQuick(tester, backend);

    await tester.tap(find.text('Configurações de Bluetooth'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('cosmic-settings não encontrado'),
      findsOneWidget,
    );
  });

  testWidgets('the home panel stays compact and does not read devices', (
    tester,
  ) async {
    final backend = _backend();
    await pumpLauncher(tester, backend: backend);

    expect(find.byType(BluetoothDevicesSection), findsNothing);
    expect(_reads(backend), 0);
  });

  testWidgets('devices are read only while the overlay is open', (
    tester,
  ) async {
    final backend = _backend();
    final h = await _openQuick(tester, backend);
    expect(_reads(backend), 1);

    await h.pressAndSettle(tester, GamepadAction.back);
    await tester.pump(const Duration(seconds: 20));

    expect(_reads(backend), 1);
  });
}
