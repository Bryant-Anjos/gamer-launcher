import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _letterColors = [
  Color(0xFF2F7BFF),
  Color(0xFF7C4DFF),
  Color(0xFF00A884),
  Color(0xFFE6533C),
  Color(0xFFF2A900),
  Color(0xFFD63384),
];
const _letterScale = 0.5;
const _cornerScale = 0.24;

/// Cor do quadrado com a inicial: sempre a mesma para o mesmo nome.
Color letterColor(String name) =>
    _letterColors[name.hashCode.abs() % _letterColors.length];

/// Ícone de um app a partir do arquivo já localizado pelo núcleo. Sem
/// arquivo (ou se ele não abrir), mostra a inicial num quadrado colorido.
/// Bitmaps são decodificados no tamanho exibido, para gastar pouca memória.
class AppIcon extends StatelessWidget {
  const AppIcon({
    super.key,
    required this.name,
    required this.iconPath,
    required this.size,
  });

  final String name;
  final String? iconPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = LetterIcon(name: name, size: size);
    final path = iconPath;
    if (path == null) return fallback;
    final file = File(path);
    if (path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.file(
        file,
        width: size,
        height: size,
        placeholderBuilder: (_) => SizedBox.square(dimension: size),
        errorBuilder: (_, _, _) => fallback,
      );
    }
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.file(
      file,
      width: size,
      height: size,
      cacheWidth: pixels,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class LetterIcon extends StatelessWidget {
  const LetterIcon({super.key, required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? '?' : trimmed.characters.first;
    final color = letterColor(trimmed);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * _cornerScale),
      ),
      child: Text(
        letter.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * _letterScale,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
