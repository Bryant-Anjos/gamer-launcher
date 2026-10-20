import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/catalog.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/widgets/app_icon.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';
import 'package:gamer_launcher/ui/widgets/icon_color.dart';
import 'package:gamer_launcher/ui/widgets/icon_color_cache.dart';

/// Ícone do app no bloco grande de favorito.
const favoriteArtIcon = 88.0;
const _badgeSize = 32.0;
const _badgeIcon = 20.0;

/// Bloco grande de favorito, da família dos cartões de destaque: degradê
/// diagonal na cor principal do ícone ([color]), ícone no meio e o nome em
/// branco numa faixa escura embaixo. Enquanto é movido, mostra o selo de
/// mover no canto.
class FavoriteTile extends StatelessWidget {
  const FavoriteTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onActivate,
    this.onFocusChange,
    this.isMoving = false,
  });

  final String label;
  final Widget icon;
  final Color color;
  final VoidCallback onActivate;
  final ValueChanged<bool>? onFocusChange;
  final bool isMoving;

  @override
  Widget build(BuildContext context) => FocusTile(
    semanticLabel: isMoving ? '$label, movendo' : label,
    onActivate: onActivate,
    onFocusChange: onFocusChange,
    child: FavoriteFace(
      label: label,
      icon: icon,
      color: color,
      isMoving: isMoving,
    ),
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
      child: IconTint(
        name: app.name,
        iconPath: app.iconPath,
        builder: (context, color) => FavoriteFace(
          label: app.name,
          icon: AppIcon(
            name: app.name,
            iconPath: app.iconPath,
            size: favoriteArtIcon,
          ),
          color: color,
          isMoving: true,
        ),
      ),
    ),
  );
}

/// A face do bloco, sem o foco. A cor nova chega com uma transição curta
/// (nenhuma com "Reduzir animações").
class FavoriteFace extends StatelessWidget {
  const FavoriteFace({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.isMoving,
  });

  final String label;
  final Widget icon;
  final Color color;
  final bool isMoving;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Color?>(
    tween: ColorTween(end: color),
    duration: Motion.of(context, Motion.tint),
    builder: (context, shown, child) => DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tileGradient(shown ?? color),
        ),
      ),
      child: child,
    ),
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

class _Caption extends StatelessWidget {
  const _Caption(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: tileCaptionColor,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.rowPaddingX,
        vertical: Dimens.rowPaddingY,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    ),
  );
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
