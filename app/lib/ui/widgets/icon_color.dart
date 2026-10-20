import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:gamer_launcher/ui/widgets/app_icon.dart';

/// Pixel com menos opacidade que isso não conta (borda e fundo do ícone).
const _minAlpha = 128;

/// Cinzas, brancos e pretos não são "a cor" do ícone.
const _minSaturation = 0.25;
const _minLightness = 0.12;
const _maxLightness = 0.9;

/// Faixas de matiz em que os pixels são agrupados (de 15 em 15 graus).
const _hueBuckets = 24;
const _fullCircle = 360.0;
const _bytesPerPixel = 4;
const _channelMax = 255;

/// Limites do degradê dos blocos: rico, mas nunca neon nem lavado, e escuro o
/// bastante para o texto branco da faixa ler bem nos dois temas.
const tileMinSaturation = 0.35;
const tileMaxSaturation = 0.65;
const tileStartLightness = 0.2;
const tileMaxLightness = 0.46;

/// O começo do degradê gira um pouco a matiz, como nos cartões de destaque.
const _startHueShift = -18.0;

/// Faixa do nome embaixo do bloco (a mesma dos cartões de destaque).
const tileCaptionColor = Color(0x8C000000);

/// A cor que mais aparece num ícone, a partir dos pixels RGBA (8 bits por
/// canal). Agrupa por matiz, pesando pela saturação, e devolve a média da
/// faixa mais forte. Sem nenhum pixel colorido, devolve `null`.
Color? dominantColor(Uint8List rgba) {
  final weights = List<double>.filled(_hueBuckets, 0);
  final sums = List.generate(_hueBuckets, (_) => [0.0, 0.0, 0.0]);
  final pixels = rgba.length ~/ _bytesPerPixel;
  for (var i = 0; i < pixels; i++) {
    final o = i * _bytesPerPixel;
    if (rgba[o + 3] < _minAlpha) continue;
    final color = Color.fromARGB(
      _channelMax,
      rgba[o],
      rgba[o + 1],
      rgba[o + 2],
    );
    final hsl = HSLColor.fromColor(color);
    if (!_isColorful(hsl)) continue;
    final bucket = (hsl.hue / _fullCircle * _hueBuckets).floor() % _hueBuckets;
    final weight = hsl.saturation;
    weights[bucket] += weight;
    sums[bucket][0] += rgba[o] * weight;
    sums[bucket][1] += rgba[o + 1] * weight;
    sums[bucket][2] += rgba[o + 2] * weight;
  }
  return _strongest(weights, sums);
}

bool _isColorful(HSLColor hsl) =>
    hsl.saturation >= _minSaturation &&
    hsl.lightness >= _minLightness &&
    hsl.lightness <= _maxLightness;

Color? _strongest(List<double> weights, List<List<double>> sums) {
  var best = -1;
  for (var i = 0; i < weights.length; i++) {
    if (weights[i] > 0 && (best < 0 || weights[i] > weights[best])) best = i;
  }
  if (best < 0) return null;
  final [r, g, b] = [for (final s in sums[best]) (s / weights[best]).round()];
  return Color.fromARGB(_channelMax, r, g, b);
}

/// Cor de quem não tem ícone colorido (ou ainda não leu o dele): a mesma do
/// quadrado com a inicial, estável para cada nome.
Color fallbackIconColor(String name) => letterColor(name.trim());

/// O degradê diagonal do bloco, da cor do ícone: mais escuro no canto de
/// cima, mais claro no de baixo.
List<Color> tileGradient(Color base) {
  final hsl = HSLColor.fromColor(base);
  final saturation = hsl.saturation.clamp(tileMinSaturation, tileMaxSaturation);
  final startHue = (hsl.hue + _startHueShift) % _fullCircle;
  return [
    HSLColor.fromAHSL(1, startHue, saturation, tileStartLightness).toColor(),
    HSLColor.fromAHSL(1, hsl.hue, saturation, tileMaxLightness).toColor(),
  ];
}
