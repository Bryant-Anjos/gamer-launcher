import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';

/// Fundo: o wallpaper escolhido (decodificado na largura da tela) com um
/// véu para o texto ficar legível, ou a cor lisa do tema. Se a imagem não
/// abrir, fica a cor lisa.
class LauncherBackground extends StatelessWidget {
  const LauncherBackground({super.key, required this.wallpaper});

  final String? wallpaper;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    final plain = ColoredBox(color: palette.background);
    final path = wallpaper;
    if (path == null) return plain;
    final media = MediaQuery.of(context);
    final pixels = (media.size.width * media.devicePixelRatio).round();
    return Stack(
      fit: StackFit.expand,
      children: [
        plain,
        Image.file(
          File(path),
          key: ValueKey(path),
          fit: BoxFit.cover,
          cacheWidth: pixels > 0 ? pixels : null,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => plain,
        ),
        ColoredBox(color: palette.scrim),
      ],
    );
  }
}
