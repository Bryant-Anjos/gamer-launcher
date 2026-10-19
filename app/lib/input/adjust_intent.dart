import 'package:flutter/widgets.dart';

/// Pedido para ajustar o controle focado (volume, brilho, horário) em vez
/// de mover o foco: esquerda é -1, direita é +1. Quem aceita declara uma
/// ação para este intent; o `InputRouter` tenta ela antes de mover o foco.
class AdjustIntent extends Intent {
  const AdjustIntent(this.step);

  final int step;
}
