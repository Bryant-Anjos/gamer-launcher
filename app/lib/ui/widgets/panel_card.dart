import 'package:flutter/material.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';

/// Título de seção ("Recentes", "Sistema"...).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Dimens.smallGap + 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

/// Superfície translúcida dos painéis, com título opcional por fora.
class PanelCard extends StatelessWidget {
  const PanelCard({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(Dimens.panelPadding),
    this.surface = true,
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;

  /// Sem superfície, só o título e o conteúdo (como os favoritos na arte).
  final bool surface;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    final body = surface
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: palette.panel,
              borderRadius: BorderRadius.circular(Dimens.radius),
              border: Border.all(color: palette.panelBorder),
            ),
            child: Padding(padding: padding, child: child),
          )
        : child;
    final heading = title;
    if (heading == null) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [SectionTitle(heading), body],
    );
  }
}

/// Texto secundário (subtítulos, horários).
class MutedText extends StatelessWidget {
  const MutedText(this.text, {super.key, this.maxLines = 1});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: LauncherPalette.of(context).textMuted),
  );
}
