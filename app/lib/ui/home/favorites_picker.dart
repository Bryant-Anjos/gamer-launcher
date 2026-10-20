import 'package:flutter/material.dart';
import 'package:gamer_launcher/input/button_names.dart';
import 'package:gamer_launcher/src/rust/api/catalog.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/app_filter.dart';
import 'package:gamer_launcher/ui/widgets/app_icon.dart';
import 'package:gamer_launcher/ui/widgets/button_hints.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';
import 'package:gamer_launcher/ui/widgets/overlay_card.dart';

const _pickerWidthFactor = 0.7;
const _pickerHeightFactor = 0.8;
const _checkSize = 22.0;

/// Escolha dos favoritos: todos os apps, com marca nos favoritos. A
/// marca/desmarca; B fecha. Fica num diálogo por cima da tela inicial.
///
/// O filtro usa a pesquisa do núcleo restrita a apps (e não um filtro local)
/// para achar do mesmo jeito que a pesquisa global: sem acentos, sem
/// maiúsculas e por sigla ("vsc" acha o VS Code).
class FavoritesPicker extends StatefulWidget {
  const FavoritesPicker({super.key});

  @override
  State<FavoritesPicker> createState() => _FavoritesPickerState();
}

class _FavoritesPickerState extends State<FavoritesPicker> {
  @override
  Widget build(BuildContext context) {
    final services = LauncherScope.of(context);
    final size = MediaQuery.sizeOf(context);
    return OverlayCard(
      title: 'Escolha os favoritos',
      hint: const ButtonHints([
        ButtonHint(PadRole.confirm, 'marca ou desmarca'),
        ButtonHint(PadRole.back, 'fecha'),
      ]),
      width: size.width * _pickerWidthFactor,
      height: size.height * _pickerHeightFactor,
      child: ValueListenableBuilder(
        valueListenable: services.controller,
        builder: (context, state, _) {
          void toggle(AppInfo app) =>
              services.controller.toggleFavorite(app.id);
          return AppFilter(
            apps: state.catalog.apps,
            onSubmit: toggle,
            builder: (context, visible) => _PickerGrid(
              apps: visible,
              favorites: state.settings.favorites,
              onToggle: toggle,
            ),
          );
        },
      ),
    );
  }
}

class _PickerGrid extends StatelessWidget {
  const _PickerGrid({
    required this.apps,
    required this.favorites,
    required this.onToggle,
  });

  final List<AppInfo> apps;
  final List<String> favorites;
  final ValueChanged<AppInfo> onToggle;

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(Dimens.smallGap),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: Dimens.appGridExtent,
      mainAxisSpacing: Dimens.gap,
      crossAxisSpacing: Dimens.gap,
    ),
    itemCount: apps.length,
    itemBuilder: (context, index) {
      final app = apps[index];
      return PickerTile(
        app: app,
        isFavorite: favorites.contains(app.id),
        autofocus: index == 0,
        onToggle: () => onToggle(app),
      );
    },
  );
}

class PickerTile extends StatelessWidget {
  const PickerTile({
    super.key,
    required this.app,
    required this.isFavorite,
    required this.onToggle,
    this.autofocus = false,
  });

  final AppInfo app;
  final bool isFavorite;
  final VoidCallback onToggle;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    return FocusTile(
      autofocus: autofocus,
      semanticLabel: '${app.name}${isFavorite ? ', favorito' : ''}',
      onActivate: onToggle,
      child: Container(
        color: isFavorite
            ? palette.accent.withValues(alpha: Opacities.selected)
            : palette.tile,
        padding: const EdgeInsets.all(Dimens.smallGap),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    name: app.name,
                    iconPath: app.iconPath,
                    size: Dimens.appGridIcon,
                  ),
                  const SizedBox(height: Dimens.smallGap),
                  Text(
                    app.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isFavorite)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: palette.accent,
                  size: _checkSize,
                  semanticLabel: 'Favorito',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
