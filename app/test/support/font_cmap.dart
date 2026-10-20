import 'dart:typed_data';

/// Codepoints que uma fonte OpenType desenha (tabela `cmap`, formatos 4 e
/// 12). Só para testes: confere que um ícone tem glifo de verdade.
Set<int> fontCodepoints(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final tables = data.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < tables; i++) {
    final record = 12 + 16 * i;
    final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'cmap') cmap = data.getUint32(record + 8);
  }
  if (cmap < 0) return {};
  final codepoints = <int>{};
  final subtables = data.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final table = cmap + data.getUint32(cmap + 4 + 8 * i + 4);
    switch (data.getUint16(table)) {
      case 4:
        _format4(data, table, codepoints);
      case 12:
        _format12(data, table, codepoints);
    }
  }
  return codepoints;
}

void _format4(ByteData data, int table, Set<int> out) {
  final segments = data.getUint16(table + 6) ~/ 2;
  for (var s = 0; s < segments; s++) {
    final end = data.getUint16(table + 14 + 2 * s);
    final start = data.getUint16(table + 16 + 2 * segments + 2 * s);
    for (var c = start; c <= end; c++) {
      out.add(c);
    }
  }
}

void _format12(ByteData data, int table, Set<int> out) {
  final groups = data.getUint32(table + 12);
  for (var g = 0; g < groups; g++) {
    final group = table + 16 + 12 * g;
    final start = data.getUint32(group);
    final end = data.getUint32(group + 4);
    for (var c = start; c <= end; c++) {
      out.add(c);
    }
  }
}
