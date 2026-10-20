import 'package:flutter/widgets.dart';
import 'package:gamer_launcher/backend/launcher_backend.dart';
import 'package:gamer_launcher/state/clock.dart';
import 'package:gamer_launcher/state/gamepad_status.dart';
import 'package:gamer_launcher/state/launcher_controller.dart';
import 'package:gamer_launcher/state/autostart_controller.dart';
import 'package:gamer_launcher/state/bluetooth_devices_controller.dart';
import 'package:gamer_launcher/state/messages.dart';
import 'package:gamer_launcher/state/power_controller.dart';
import 'package:gamer_launcher/state/quick_controls_controller.dart';
import 'package:gamer_launcher/state/system_monitor.dart';
import 'package:gamer_launcher/state/ui_sounds.dart';

/// Focos que o app move por fora da árvore (LB/RB levam o foco à seção).
class LauncherFocus {
  LauncherFocus()
    : nav = List.unmodifiable([
        for (final section in Section.values)
          FocusNode(debugLabel: 'nav-${section.name}'),
      ]);

  final List<FocusNode> nav;

  void dispose() {
    for (final node in nav) {
      node.dispose();
    }
  }
}

/// Serviços compartilhados pelas telas. Ficam acima do `Navigator`, para
/// os diálogos (controle rápido, favoritos) também os enxergarem.
class LauncherServices {
  const LauncherServices({
    required this.backend,
    required this.controller,
    required this.quickControls,
    required this.monitor,
    required this.gamepad,
    required this.clock,
    required this.focus,
    required this.messages,
    required this.coreVersion,
    required this.openFavoritesPicker,
    required this.power,
    required this.autostart,
    required this.openPowerMenu,
    required this.closeLauncher,
    required this.sounds,
    required this.bluetoothDevices,
    required this.openSearch,
  });

  final LauncherBackend backend;
  final LauncherController controller;
  final QuickControlsController quickControls;
  final SystemMonitor monitor;
  final GamepadStatus gamepad;
  final Clock clock;
  final LauncherFocus focus;
  final LauncherMessages messages;
  final String coreVersion;
  final VoidCallback openFavoritesPicker;
  final PowerController power;
  final AutostartController autostart;
  final VoidCallback openPowerMenu;
  final VoidCallback closeLauncher;
  final UiSounds sounds;
  final BluetoothDevicesController bluetoothDevices;

  /// Abre a pesquisa global com o texto já digitado (vazio pelo Y).
  final ValueChanged<String> openSearch;
}

class LauncherScope extends InheritedWidget {
  const LauncherScope({
    super.key,
    required this.services,
    required super.child,
  });

  final LauncherServices services;

  static LauncherServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LauncherScope>();
    assert(scope != null, 'LauncherScope ausente acima de $context');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(LauncherScope oldWidget) =>
      !identical(oldWidget.services, services);
}
