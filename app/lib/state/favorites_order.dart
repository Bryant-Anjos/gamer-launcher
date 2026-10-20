import 'package:flutter/widgets.dart';

/// Nova lista com o item de [from] em [to] (limitado às pontas); a original
/// não muda.
List<String> moveItem(List<String> order, int from, int to) {
  final target = to.clamp(0, order.length - 1);
  final next = [...order];
  final item = next.removeAt(from);
  next.insert(target, item);
  return next;
}

/// Para onde o favorito na posição [index] vai numa grade de [columns]
/// colunas: um passo para os lados, uma fileira para cima ou para baixo.
/// Nas pontas fica onde está (para baixo na última fileira vai ao fim).
int moveTarget(
  int index,
  TraversalDirection direction, {
  required int columns,
  required int length,
}) {
  final last = length - 1;
  return switch (direction) {
    TraversalDirection.left => index > 0 ? index - 1 : index,
    TraversalDirection.right => index < last ? index + 1 : index,
    TraversalDirection.up => index >= columns ? index - columns : index,
    TraversalDirection.down => (index + columns).clamp(index, last),
  };
}
