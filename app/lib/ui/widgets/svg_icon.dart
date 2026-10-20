import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Desenho próprio (SVG de traço) na cor e no tamanho do `IconTheme`, para
/// ficar ao lado dos ícones do Material com o mesmo peso.
class SvgIcon extends StatelessWidget {
  const SvgIcon(this.asset, {super.key, this.color, this.semanticLabel});

  final String asset;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 24;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      colorFilter: ColorFilter.mode(
        color ?? theme.color ?? Colors.white,
        BlendMode.srcIn,
      ),
    );
  }
}

/// Controle de duas metades (estilo portátil da Nintendo), para a opção
/// Nintendo dos botões do controle.
class PadIcon extends StatelessWidget {
  const PadIcon({super.key});

  static const asset = 'assets/icons/pads/handheld.svg';

  @override
  Widget build(BuildContext context) => const SvgIcon(asset);
}
