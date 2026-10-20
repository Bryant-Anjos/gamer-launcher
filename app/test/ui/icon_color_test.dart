import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/ui/widgets/app_icon.dart';
import 'package:gamer_launcher/ui/widgets/icon_color.dart';

/// Imagem RGBA sintética com os pixels dados, na ordem.
Uint8List _rgba(List<Color> pixels) => Uint8List.fromList([
  for (final c in pixels) ...[
    (c.r * 255).round(),
    (c.g * 255).round(),
    (c.b * 255).round(),
    (c.a * 255).round(),
  ],
]);

/// Folga para o arredondamento das cores em 8 bits.
const _rounding = 0.01;

List<Color> _many(Color color, int count) => List.filled(count, color);

/// Contraste WCAG entre duas cores opacas.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('dominantColor', () {
    test('a solid image gives its own color', () {
      const red = Color(0xFFD03030);
      final color = dominantColor(_rgba(_many(red, 64)));

      expect(color, isNotNull);
      expect(color!.toARGB32(), red.toARGB32());
    });

    test('transparent pixels are ignored', () {
      const blue = Color(0xFF2F6BD0);
      final pixels = [
        ..._many(const Color(0x00FF0000), 200),
        ..._many(blue, 10),
      ];

      expect(dominantColor(_rgba(pixels))?.toARGB32(), blue.toARGB32());
    });

    test('grays, whites and blacks are ignored', () {
      const green = Color(0xFF2FA05A);
      final pixels = [
        ..._many(const Color(0xFF808080), 100),
        ..._many(Colors.white, 100),
        ..._many(Colors.black, 100),
        ..._many(green, 8),
      ];

      expect(dominantColor(_rgba(pixels))?.toARGB32(), green.toARGB32());
    });

    test('the most common hue wins over a rarer one', () {
      const orange = Color(0xFFE07020);
      const purple = Color(0xFF7030C0);
      final pixels = [..._many(purple, 10), ..._many(orange, 40)];

      expect(dominantColor(_rgba(pixels))?.toARGB32(), orange.toARGB32());
    });

    test('an empty or colorless image gives no color', () {
      expect(dominantColor(Uint8List(0)), isNull);
      expect(dominantColor(_rgba(_many(const Color(0xFF777777), 50))), isNull);
      expect(dominantColor(_rgba(_many(const Color(0x00000000), 50))), isNull);
    });

    test('a truncated buffer only reads whole pixels', () {
      final bytes = Uint8List.fromList([
        ..._rgba([Colors.red]),
        1,
        2,
      ]);

      expect(dominantColor(bytes), isNotNull);
    });
  });

  group('fallbackIconColor', () {
    test('is stable for the same name and matches the initial icon', () {
      expect(fallbackIconColor('Spotify'), fallbackIconColor('Spotify'));
      expect(fallbackIconColor('Spotify'), letterColor('Spotify'));
      expect(fallbackIconColor('  Spotify '), letterColor('Spotify'));
    });

    test('is always opaque, even for an empty name', () {
      expect(fallbackIconColor('').a, 1);
    });
  });

  group('tileGradient', () {
    const samples = [
      Color(0xFF00FF00), // neon
      Color(0xFFFFFF00), // amarelo forte
      Color(0xFF0000FF),
      Color(0xFF3A2A78),
      Color(0xFFFF8FB0), // pastel
      Color(0xFF101010), // quase preto
    ];

    test('goes diagonally from a darker to a lighter tone', () {
      for (final base in samples) {
        final [start, end] = tileGradient(base);
        expect(
          HSLColor.fromColor(start).lightness,
          lessThan(HSLColor.fromColor(end).lightness),
        );
      }
    });

    test('is never neon nor washed out', () {
      for (final base in samples) {
        for (final color in tileGradient(base)) {
          final hsl = HSLColor.fromColor(color);
          expect(
            hsl.saturation,
            lessThanOrEqualTo(tileMaxSaturation + _rounding),
          );
          expect(
            hsl.lightness,
            lessThanOrEqualTo(tileMaxLightness + _rounding),
          );
        }
      }
    });

    test('keeps the hue of the icon', () {
      const base = Color(0xFF2F7BFF);
      final [_, end] = tileGradient(base);

      expect(
        HSLColor.fromColor(end).hue,
        closeTo(HSLColor.fromColor(base).hue, 1),
      );
    });

    test('white text on the caption band is readable', () {
      for (final base in samples) {
        for (final color in tileGradient(base)) {
          final band = Color.alphaBlend(tileCaptionColor, color);
          expect(_contrast(Colors.white, band), greaterThanOrEqualTo(4.5));
        }
      }
    });
  });
}
