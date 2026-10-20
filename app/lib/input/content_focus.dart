import 'package:flutter/widgets.dart';

/// Itens que começam até essa distância da borda esquerda do conteúdo contam
/// como a primeira coluna (as bordas de foco e os recuos variam um pouco).
const _columnTolerance = 48.0;

bool _isTextField(FocusNode node) =>
    node.context?.findAncestorWidgetOfExactType<EditableText>() != null;

/// Primeiro item do conteúdo de uma seção: o mais alto da coluna mais à
/// esquerda, ao lado da navegação. Na tela inicial isso é o cartão
/// Continuar, e não a pesquisa, que fica no alto mas à direita. Campos de
/// texto (o filtro de Aplicativos) só contam se não houver outro item:
/// digitar com um app focado já leva ao filtro.
FocusNode? firstItemIn(FocusNode root) {
  final focusable = root.traversalDescendants
      .where((node) => node.canRequestFocus && node.context != null)
      .toList();
  final items = focusable.where((node) => !_isTextField(node)).toList();
  if (items.isEmpty) return focusable.isEmpty ? null : focusable.first;
  final left = items.map((node) => node.rect.left).reduce(_min);
  final column = items.where(
    (node) => node.rect.left <= left + _columnTolerance,
  );
  return column.reduce((a, b) => b.rect.top < a.rect.top ? b : a);
}

double _min(double a, double b) => a < b ? a : b;
