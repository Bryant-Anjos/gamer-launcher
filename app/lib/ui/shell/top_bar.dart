import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';
import 'package:gamer_launcher/ui/widgets/poller_attachment.dart';
import 'package:gamer_launcher/util/formatting.dart';

IconData wifiIcon(QuickControls? controls) => switch (controls?.wifi.enabled) {
  true => Icons.wifi_rounded,
  false => Icons.wifi_off_rounded,
  null => Icons.signal_wifi_statusbar_null_rounded,
};

IconData volumeIcon(LevelReading? volume) {
  if (volume?.percent == null) return Icons.volume_off_outlined;
  return volume!.muted || volume.percent == 0
      ? Icons.volume_off_rounded
      : Icons.volume_up_rounded;
}

/// Abaixo disso o ícone avisa que a bateria está fraca.
const lowBatteryPercent = 15;

IconData batteryIcon(BatteryReading battery) {
  if (battery.charging) return Icons.battery_charging_full_rounded;
  return switch (battery.percent) {
    < lowBatteryPercent => Icons.battery_alert_rounded,
    < 30 => Icons.battery_2_bar_rounded,
    < 50 => Icons.battery_3_bar_rounded,
    < 70 => Icons.battery_4_bar_rounded,
    < 90 => Icons.battery_5_bar_rounded,
    _ => Icons.battery_full_rounded,
  };
}

/// Ícone e porcentagem da bateria; o rótulo diz se carrega ou está fraca.
class BatteryIndicator extends StatelessWidget {
  const BatteryIndicator({super.key, required this.battery});

  final BatteryReading battery;

  @override
  Widget build(BuildContext context) {
    final isLow = !battery.charging && battery.percent < lowBatteryPercent;
    final label = battery.charging
        ? 'Bateria carregando'
        : isLow
        ? 'Bateria fraca'
        : 'Bateria';
    final textTheme = Theme.of(context).textTheme;
    final color = isLow ? Theme.of(context).colorScheme.error : null;
    return Row(
      children: [
        // deitada, a bateria ocupa a mesma largura dos outros ícones da barra
        RotatedBox(
          quarterTurns: 1,
          child: Icon(
            batteryIcon(battery),
            size: Dimens.statusIcon,
            semanticLabel: label,
            color: color,
          ),
        ),
        const SizedBox(width: Dimens.tinyGap),
        Text(
          '${battery.percent}%',
          style: textTheme.labelLarge?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Barra superior: Wi-Fi, volume, controle conectado, bateria, hora e data.
class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final services = LauncherScope.of(context);
    return PollerAttachment(
      pollers: [
        services.quickControls.poller,
        services.gamepad.poller,
        services.power.poller,
      ],
      child: SizedBox(
        height: Dimens.topBarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimens.gutter),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ValueListenableBuilder(
                valueListenable: services.quickControls,
                builder: (context, controls, _) => Row(
                  children: [
                    Icon(
                      wifiIcon(controls),
                      size: Dimens.statusIcon,
                      semanticLabel: 'Wi-Fi',
                    ),
                    const SizedBox(width: Dimens.gap),
                    Icon(
                      volumeIcon(controls?.volume),
                      size: Dimens.statusIcon,
                      semanticLabel: 'Volume',
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder(
                valueListenable: services.gamepad,
                builder: (context, connected, _) => connected
                    ? const Padding(
                        padding: EdgeInsets.only(left: Dimens.gap),
                        child: Icon(
                          Icons.sports_esports_rounded,
                          size: Dimens.statusIcon,
                          semanticLabel: 'Controle conectado',
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              ValueListenableBuilder(
                valueListenable: services.power,
                builder: (context, battery, _) => battery == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(left: Dimens.gap),
                        child: BatteryIndicator(battery: battery),
                      ),
              ),
              const SizedBox(width: Dimens.gutter),
              ValueListenableBuilder(
                valueListenable: services.clock,
                builder: (context, now, _) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatClock(now),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    MutedText(formatShortDate(now)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
