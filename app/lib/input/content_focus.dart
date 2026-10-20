import 'package:flutter/widgets.dart';

/// Itens que começam até essa distância da borda esquerda do conteúdo contam
/// como a primeira coluna (as bordas de foco e os recuos variam um pouco).
const _columnTolerance = 48.0;

/// Primeiro item do conteúdo de uma seção: o mais alto da coluna mais à
/// esquerda, ao lado da navegação. Na tela inicial isso é o cartão
/// Continuar, e não a pesquisa, que fica no alto mas à direita.
FocusNode? firstItemIn(FocusNode root) {
  final items = root.traversalDescendants
      .where((node) => node.canRequestFocus && node.context != null)
      .toList();
  if (items.isEmpty) return null;
  final left = items.map((node) => node.rect.left).reduce(_min);
  final column = items.where(
    (node) => node.rect.left <= left + _columnTolerance,
  );
  return column.reduce((a, b) => b.rect.top < a.rect.top ? b : a);
}

double _min(double a, double b) => a < b ? a : b;
