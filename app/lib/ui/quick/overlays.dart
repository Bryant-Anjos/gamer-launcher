import 'package:flutter/material.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/home/favorites_picker.dart';
import 'package:gamer_launcher/ui/power/power_menu.dart';
import 'package:gamer_launcher/ui/quick/quick_controls_panel.dart';

const _barrierColor = Color(0x8C000000);
const quickControlsRouteName = 'quick-controls';
const favoritesRouteName = 'favorites-picker';
const powerMenuRouteName = 'power-menu';

Future<void> _showOverlay(
  NavigatorState navigator,
  String name,
  Widget Function(BuildContext context) builder,
) => navigator.push(
  RawDialogRoute<void>(
    settings: RouteSettings(name: name),
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    barrierColor: _barrierColor,
    transitionDuration: Motion.of(navigator.context, Motion.overlay),
    pageBuilder: (context, _, _) => builder(context),
  ),
);

/// Controle rápido por cima de qualquer seção (botão Start; B fecha).
Future<void> showQuickControls(NavigatorState navigator) => _showOverlay(
  navigator,
  quickControlsRouteName,
  (context) => SafeArea(
    child: Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Dimens.gutter,
          Dimens.topBarHeight + Dimens.smallGap,
          Dimens.gutter,
          Dimens.gutter,
        ),
        child: SizedBox(
          width: Dimens.sidePanelWidth,
          // com muitos dispositivos pareados o painel rola
          child: SingleChildScrollView(
            // fundo opaco por baixo do painel translúcido: a tela inicial
            // não aparece através dele (como nos outros diálogos)
            child: Material(
              color: LauncherPalette.of(context).background,
              borderRadius: BorderRadius.circular(Dimens.radius),
              child: const QuickControlsPanel(
                autofocus: true,
                showDevices: true,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> showFavoritesPicker(NavigatorState navigator) => _showOverlay(
  navigator,
  favoritesRouteName,
  (context) => const FavoritesPicker(),
);

Future<void> showPowerMenu(NavigatorState navigator) =>
    _showOverlay(navigator, powerMenuRouteName, (context) => const PowerMenu());
