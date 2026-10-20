import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/state/bluetooth_devices_controller.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/menu_row.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';
import 'package:gamer_launcher/ui/widgets/poller_attachment.dart';

const bluetoothOffText = 'Ligue o Bluetooth para ver os dispositivos.';
const noPairedDevicesText =
    'Nenhum dispositivo pareado. Pareie nas configurações de Bluetooth.';
const _progressSize = 18.0;
const _progressStroke = 2.0;

String _status(PairedDevice device, {required bool busy}) =>
    switch ((busy, device.connected)) {
      (true, true) => 'Desconectando...',
      (true, false) => 'Conectando...',
      (false, true) => 'Conectado',
      (false, false) => 'Desconectado',
    };

/// Dispositivos pareados (A conecta ou desconecta) e os atalhos para as
/// páginas de Bluetooth e de rede do sistema. Só no controle rápido
/// sobreposto: a lista é lida enquanto ele está aberto.
class BluetoothDevicesSection extends StatelessWidget {
  const BluetoothDevicesSection({super.key, required this.bluetoothOn});

  /// `false` com o Bluetooth desligado; `null` se ainda não se sabe.
  final bool? bluetoothOn;

  @override
  Widget build(BuildContext context) {
    final services = LauncherScope.of(context);
    final devices = services.bluetoothDevices;
    return PollerAttachment(
      pollers: [devices.poller],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Heading('Dispositivos Bluetooth'),
          if (bluetoothOn == false)
            const MutedText(bluetoothOffText, maxLines: 2)
          else
            ValueListenableBuilder(
              valueListenable: devices,
              builder: (context, state, _) =>
                  _DeviceList(state: state, onToggle: devices.toggle),
            ),
          const SizedBox(height: Dimens.gap),
          const _Heading('Abrir no sistema'),
          const _SettingsShortcuts(),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Dimens.smallGap),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.state, required this.onToggle});

  final BluetoothDevicesState state;
  final ValueChanged<PairedDevice> onToggle;

  @override
  Widget build(BuildContext context) {
    final devices = state.devices;
    final error = state.error;
    if (devices == null && error != null) {
      return Tooltip(message: error, child: const MutedText('Indisponível'));
    }
    if (devices == null) return const MutedText('Lendo...');
    if (devices.isEmpty) {
      return const MutedText(noPairedDevicesText, maxLines: 2);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, device) in devices.indexed) ...[
          if (index > 0) const SizedBox(height: Dimens.smallGap),
          _DeviceRow(
            device: device,
            busy: state.isBusy(device.address),
            onToggle: () => onToggle(device),
          ),
        ],
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.busy,
    required this.onToggle,
  });

  final PairedDevice device;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    final status = _status(device, busy: busy);
    return MenuRow(
      icon: device.connected
          ? Icons.bluetooth_connected_rounded
          : Icons.bluetooth_rounded,
      label: device.name,
      subtitle: status,
      semanticLabel: '${device.name}: $status',
      background: palette.tile,
      onActivate: onToggle,
      trailing: busy
          ? const SizedBox.square(
              dimension: _progressSize,
              child: CircularProgressIndicator(strokeWidth: _progressStroke),
            )
          : null,
    );
  }
}

class _SettingsShortcuts extends StatelessWidget {
  const _SettingsShortcuts();

  @override
  Widget build(BuildContext context) {
    final controller = LauncherScope.of(context).controller;
    final tile = LauncherPalette.of(context).tile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuRow(
          icon: Icons.settings_bluetooth_rounded,
          label: 'Configurações de Bluetooth',
          background: tile,
          onActivate: () =>
              controller.openSettingsPage('bluetooth', 'de Bluetooth'),
        ),
        const SizedBox(height: Dimens.smallGap),
        MenuRow(
          icon: Icons.network_wifi_rounded,
          label: 'Configurações de rede',
          background: tile,
          onActivate: () => controller.openSettingsPage('wireless', 'de rede'),
        ),
      ],
    );
  }
}
