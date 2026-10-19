import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
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

/// Barra superior: Wi-Fi, volume, controle conectado, hora e data.
class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final services = LauncherScope.of(context);
    final palette = LauncherPalette.of(context);
    return PollerAttachment(
      pollers: [services.quickControls.poller, services.gamepad.poller],
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
                    Text(
                      formatShortDate(now),
                      style: TextStyle(color: palette.textMuted, fontSize: 13),
                    ),
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
