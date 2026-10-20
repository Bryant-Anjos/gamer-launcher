import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/quick/bluetooth_devices.dart';
import 'package:gamer_launcher/ui/shell/top_bar.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';
import 'package:gamer_launcher/ui/widgets/level_slider.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';
import 'package:gamer_launcher/ui/widgets/poller_attachment.dart';

const unavailableLabel = 'Indisponível';

/// Painel de controle rápido: Wi-Fi, Bluetooth, modo escuro do sistema,
/// volume e brilho. A luz noturna fica de fora (sem API estável no
/// COSMIC). Item que não pôde ser lido aparece como indisponível.
class QuickControlsPanel extends StatelessWidget {
  const QuickControlsPanel({
    super.key,
    this.autofocus = false,
    this.showDevices = false,
  });

  /// No painel sobreposto (botão Start) o primeiro item já vem focado.
  final bool autofocus;

  /// Dispositivos Bluetooth e atalhos: só no painel sobreposto, para o da
  /// tela inicial continuar do tamanho dos cartões.
  final bool showDevices;

  @override
  Widget build(BuildContext context) {
    final quick = LauncherScope.of(context).quickControls;
    return PollerAttachment(
      pollers: [quick.poller],
      child: PanelCard(
        child: ValueListenableBuilder(
          valueListenable: quick,
          builder: (context, controls, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: QuickToggle(
                      icon: Icons.wifi_rounded,
                      label: 'Wi-Fi',
                      reading: controls?.wifi,
                      onText: controls?.wifiName ?? 'Ligado',
                      onChanged: quick.setWifi,
                      autofocus: autofocus,
                    ),
                  ),
                  Expanded(
                    child: QuickToggle(
                      icon: Icons.bluetooth_rounded,
                      label: 'Bluetooth',
                      reading: controls?.bluetooth,
                      onChanged: quick.setBluetooth,
                    ),
                  ),
                  Expanded(
                    child: QuickToggle(
                      icon: Icons.dark_mode_rounded,
                      label: 'Modo escuro',
                      reading: controls?.darkMode,
                      onChanged: quick.setDarkMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dimens.gap),
              LevelSlider(
                icon: volumeIcon(controls?.volume),
                label: 'Volume',
                value: controls?.volume.percent,
                onChanged: quick.setVolume,
              ),
              LevelSlider(
                icon: Icons.light_mode_rounded,
                label: 'Brilho',
                value: controls?.brightness.percent,
                onChanged: quick.setBrightness,
              ),
              if (showDevices) ...[
                const SizedBox(height: Dimens.gap),
                BluetoothDevicesSection(
                  bluetoothOn: controls?.bluetooth.enabled,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão liga/desliga com o estado embaixo ("Ativado", nome da rede...).
class QuickToggle extends StatelessWidget {
  const QuickToggle({
    super.key,
    required this.icon,
    required this.label,
    required this.reading,
    required this.onChanged,
    this.onText = 'Ativado',
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final ToggleReading? reading;
  final ValueChanged<bool> onChanged;
  final String onText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    final enabled = reading?.enabled;
    final status = switch (enabled) {
      true => onText,
      false => 'Desativado',
      null => reading == null ? 'Lendo...' : unavailableLabel,
    };
    final isOn = enabled ?? false;
    final tile = FocusTile(
      autofocus: autofocus && enabled != null,
      borderRadius: Dimens.smallRadius,
      semanticLabel: '$label: $status',
      onActivate: enabled == null ? null : () => onChanged(!enabled),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Container(
              width: Dimens.toggleBox,
              height: Dimens.toggleBox,
              decoration: BoxDecoration(
                color: isOn ? palette.accent : palette.tile,
                borderRadius: BorderRadius.circular(Dimens.radius),
              ),
              child: Icon(
                icon,
                color: isOn ? palette.onAccent : palette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            MutedText(status),
          ],
        ),
      ),
    );
    final error = reading?.error;
    if (enabled != null) return tile;
    final dimmed = Opacity(opacity: Opacities.disabled, child: tile);
    return error == null ? dimmed : Tooltip(message: error, child: dimmed);
  }
}
