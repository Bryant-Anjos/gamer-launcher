import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/catalog.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/app_icon.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';

const addFavoriteLabel = 'Adicionar';
const _captionWidth = Dimens.favoriteTile + Dimens.gap;

/// Grade de apps favoritos e o botão "Adicionar" (abre a escolha).
class FavoritesPanel extends StatelessWidget {
  const FavoritesPanel({super.key, required this.favorites});

  final List<AppInfo> favorites;

  @override
  Widget build(BuildContext context) {
    final services = LauncherScope.of(context);
    return PanelCard(
      title: 'Aplicativos favoritos',
      surface: false,
      child: Wrap(
        spacing: Dimens.gap,
        runSpacing: Dimens.smallGap,
        children: [
          for (final app in favorites)
            FavoriteTile(
              label: app.name,
              icon: AppIcon(
                name: app.name,
                iconPath: app.iconPath,
                size: Dimens.favoriteIcon,
              ),
              onActivate: () => services.controller.launchApp(app.id),
            ),
          FavoriteTile(
            label: addFavoriteLabel,
            alwaysShowLabel: true,
            icon: const Icon(Icons.add_rounded, size: Dimens.favoriteIcon),
            onActivate: services.openFavoritesPicker,
          ),
        ],
      ),
    );
  }
}

/// Quadrado com ícone; o nome aparece embaixo quando focado (sempre, no
/// "Adicionar"), para a grade ficar limpa como na arte.
class FavoriteTile extends StatefulWidget {
  const FavoriteTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onActivate,
    this.alwaysShowLabel = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback onActivate;
  final bool alwaysShowLabel;

  @override
  State<FavoriteTile> createState() => _FavoriteTileState();
}

class _FavoriteTileState extends State<FavoriteTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    final showLabel = widget.alwaysShowLabel || _focused;
    return SizedBox(
      width: _captionWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FocusTile(
            semanticLabel: widget.label,
            onActivate: widget.onActivate,
            onFocusChange: (focused) => setState(() => _focused = focused),
            child: Container(
              width: Dimens.favoriteTile,
              height: Dimens.favoriteTile,
              color: palette.tile,
              alignment: Alignment.center,
              child: widget.icon,
            ),
          ),
          const SizedBox(height: 6),
          Opacity(opacity: showLabel ? 1 : 0, child: MutedText(widget.label)),
        ],
      ),
    );
  }
}
