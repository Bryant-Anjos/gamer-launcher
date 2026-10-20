import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/catalog.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/widgets/app_icon.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';

/// Ícone do app no bloco grande de favorito.
const favoriteArtIcon = 88.0;
const _captionAlpha = 0.06;
const _badgeSize = 32.0;
const _badgeIcon = 20.0;

/// Bloco grande de favorito, com a forma dos cartões de destaque: ícone no
/// meio e o nome numa faixa embaixo. Enquanto é movido, mostra o selo de
/// mover no canto.
class FavoriteTile extends StatelessWidget {
  const FavoriteTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onActivate,
    this.onFocusChange,
    this.isMoving = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback onActivate;
  final ValueChanged<bool>? onFocusChange;
  final bool isMoving;

  @override
  Widget build(BuildContext context) => FocusTile(
    semanticLabel: isMoving ? '$label, movendo' : label,
    onActivate: onActivate,
    onFocusChange: onFocusChange,
    child: _FavoriteFace(label: label, icon: icon, isMoving: isMoving),
  );
}

/// O que acompanha o ponteiro ao arrastar um favorito.
class FavoriteDragImage extends StatelessWidget {
  const FavoriteDragImage(this.app, {super.key});

  final AppInfo app;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: 1 - Opacities.selected,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(Dimens.radius),
      child: _FavoriteFace(
        label: app.name,
        icon: AppIcon(
          name: app.name,
          iconPath: app.iconPath,
          size: favoriteArtIcon,
        ),
        isMoving: true,
      ),
    ),
  );
}

class _FavoriteFace extends StatelessWidget {
  const _FavoriteFace({
    required this.label,
    required this.icon,
    required this.isMoving,
  });

  final String label;
  final Widget icon;
  final bool isMoving;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    return ColoredBox(
      color: isMoving
          ? Color.alphaBlend(
              palette.accent.withValues(alpha: Opacities.selected),
              palette.tile,
            )
          : palette.tile,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: Center(child: icon)),
              _Caption(label),
            ],
          ),
          if (isMoving)
            const Positioned(
              top: Dimens.smallGap,
              right: Dimens.smallGap,
              child: _MovingBadge(),
            ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    return Container(
      color: palette.textPrimary.withValues(alpha: _captionAlpha),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.rowPaddingX,
        vertical: Dimens.rowPaddingY,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MovingBadge extends StatelessWidget {
  const _MovingBadge();

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    return Container(
      width: _badgeSize,
      height: _badgeSize,
      decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
      child: Icon(
        Icons.open_with_rounded,
        size: _badgeIcon,
        color: palette.onAccent,
      ),
    );
  }
}
