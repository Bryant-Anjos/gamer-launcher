import 'package:flutter/material.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/home/favorites_picker.dart';
import 'package:gamer_launcher/ui/power/power_menu.dart';
import 'package:gamer_launcher/ui/quick/quick_controls_panel.dart';

const _barrierColor = Color(0x8C000000);
const _overlayMotion = Duration(milliseconds: 160);
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
    transitionDuration: _overlayMotion,
    pageBuilder: (context, _, _) => builder(context),
  ),
);

/// Controle rápido por cima de qualquer seção (botão Start; B fecha).
Future<void> showQuickControls(NavigatorState navigator) => _showOverlay(
  navigator,
  quickControlsRouteName,
  (context) => const SafeArea(
    child: Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Dimens.gutter,
          Dimens.topBarHeight + Dimens.smallGap,
          Dimens.gutter,
          Dimens.gutter,
        ),
        child: SizedBox(
          width: Dimens.sidePanelWidth,
          child: Material(
            type: MaterialType.transparency,
            child: QuickControlsPanel(autofocus: true),
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
