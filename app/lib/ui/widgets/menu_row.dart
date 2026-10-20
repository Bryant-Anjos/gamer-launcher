import 'package:flutter/material.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';

/// Linha de menu ou lista: ícone, rótulo, linha secundária opcional e algo
/// à direita (estado, ação). A mesma superfície dos recentes e das chaves de
/// Configurações; [emphasized] pinta na cor de destaque (a ação principal).
class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onActivate,
    this.autofocus = false,
    this.emphasized = false,
    this.focusNode,
    this.semanticLabel,
    this.leading,
    this.background,
  });

  /// Ícone do Material; [leading] tem prioridade (ícone de app, SVG).
  final IconData? icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onActivate;
  final bool autofocus;
  final bool emphasized;
  final FocusNode? focusNode;
  final String? semanticLabel;

  /// No lugar do ícone (o ícone de um app, por exemplo).
  final Widget? leading;

  /// Dentro de um painel, a linha usa a cor dos blocos (`tile`) para não
  /// sumir na superfície translúcida.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    final foreground = emphasized ? palette.onAccent : palette.textPrimary;
    final extra = trailing;
    return FocusTile(
      autofocus: autofocus,
      focusNode: focusNode,
      semanticLabel: semanticLabel ?? label,
      borderRadius: Dimens.smallRadius,
      onActivate: onActivate,
      child: Container(
        color: emphasized ? palette.accent : (background ?? palette.panel),
        padding: const EdgeInsets.symmetric(
          horizontal: Dimens.rowPaddingX,
          vertical: Dimens.rowPaddingY,
        ),
        child: Row(
          children: [
            IconTheme.merge(
              data: IconThemeData(color: foreground),
              child: leading ?? Icon(icon),
            ),
            const SizedBox(width: Dimens.iconGap),
            Expanded(child: _Texts(label, subtitle, foreground)),
            if (extra != null) ...[
              const SizedBox(width: Dimens.smallGap),
              extra,
            ],
          ],
        ),
      ),
    );
  }
}

class _Texts extends StatelessWidget {
  const _Texts(this.label, this.subtitle, this.color);

  final String label;
  final String? subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final line = subtitle;
    final title = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color),
    );
    if (line == null) return title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [title, MutedText(line)],
    );
  }
}
