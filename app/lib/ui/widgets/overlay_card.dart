import 'package:flutter/material.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';

/// Moldura dos diálogos sobrepostos (favoritos, Energia, pesquisa): fundo
/// opaco do tema com a borda dos painéis, título e a dica dos botões.
class OverlayCard extends StatelessWidget {
  const OverlayCard({
    super.key,
    required this.title,
    required this.child,
    this.hint,
    this.width,
    this.height,
  });

  final String title;

  /// Dica dos botões, embaixo do título ("A escolhe · B fecha").
  final Widget? hint;
  final Widget child;
  final double? width;

  /// Com altura fixa o conteúdo ocupa o resto (listas que rolam); sem ela o
  /// cartão abraça o conteúdo.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    final hasHeight = height != null;
    final help = hint;
    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: palette.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dimens.radius),
            side: BorderSide(color: palette.panelBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Dimens.gutter),
            child: Column(
              mainAxisSize: hasHeight ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(title),
                ?help,
                const SizedBox(height: Dimens.gap),
                if (hasHeight) Expanded(child: child) else child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
