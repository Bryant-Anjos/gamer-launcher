import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Desenhos próprios das ações de energia, no estilo dos sistemas (COSMIC,
/// GNOME, Windows): traço de 2 px com pontas arredondadas, como os ícones
/// arredondados do Material ao lado.
enum PowerGlyph {
  suspend('suspend'),
  restart('restart'),
  shutdown('shutdown'),
  logOut('log_out'),
  closeLauncher('close_launcher');

  const PowerGlyph(this._file);

  final String _file;

  String get asset => 'assets/icons/power/$_file.svg';
}

/// Ícone de energia na cor e no tamanho do `IconTheme`, como um `Icon`.
class PowerIcon extends StatelessWidget {
  const PowerIcon(this.glyph, {super.key, this.color, this.semanticLabel});

  final PowerGlyph glyph;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 24;
    return SvgPicture.asset(
      glyph.asset,
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
