import 'dart:math' as math;

import 'package:flutter/material.dart';

const _fullPercent = 100.0;
const _ringStroke = 4.0;
const _lineStroke = 2.0;
const _fillAlpha = 0.25;
const _trackAlpha = 0.2;
const _startAngle = -math.pi / 2;

/// Anel de 0 a 100% (o círculo à esquerda de cada linha do painel Sistema).
class RingGauge extends StatelessWidget {
  const RingGauge({
    super.key,
    required this.percent,
    required this.color,
    required this.size,
  });

  final double percent;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _RingPainter(percent.clamp(0, _fullPercent), color),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.percent, this.color);

  final double percent;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(_ringStroke / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringStroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      stroke..color = color.withValues(alpha: _trackAlpha),
    );
    canvas.drawArc(
      arc,
      _startAngle,
      math.pi * 2 * percent / _fullPercent,
      false,
      stroke..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.percent != percent || old.color != color;
}

/// Linha do histórico (0 a 100%), com área preenchida embaixo.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    required this.capacity,
  });

  final List<double> values;
  final Color color;

  /// Quantos pontos cabem na largura (o histórico cresce da direita).
  final int capacity;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SparklinePainter(values, color, capacity),
    size: Size.infinite,
  );
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color, this.capacity);

  final List<double> values;
  final Color color;
  final int capacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || capacity < 2) return;
    final step = size.width / (capacity - 1);
    final offset = (capacity - values.length) * step;
    Offset point(int i) => Offset(
      offset + i * step,
      size.height -
          values[i].clamp(0, _fullPercent) / _fullPercent * size.height,
    );
    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(point(i).dx, point(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(point(values.length - 1).dx, size.height)
      ..lineTo(offset, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: _fillAlpha));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _lineStroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      !identical(old.values, values) || old.color != color;
}
