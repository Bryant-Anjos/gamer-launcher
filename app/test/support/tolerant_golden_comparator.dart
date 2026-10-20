
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fração máxima de pixels diferentes que ainda conta como a mesma imagem.
///
/// A renderização de texto e de gradientes varia um pouco de um sistema para
/// outro (a CI do GitHub mediu de 0,01% a 0,03% contra imagens geradas aqui).
/// 0,1% absorve esse ruído, mas uma mudança de verdade (um tile, uma linha de
/// texto, um ícone) passa disso com folga.
const goldenTolerance = 0.001;

bool withinGoldenTolerance(
  ComparisonResult result, [
  double tolerance = goldenTolerance,
]) => result.passed || result.diffPercent <= tolerance;

/// Como o comparador padrão do Flutter, mas aceitando o ruído de renderização
/// descrito em [goldenTolerance].
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(super.testFile, {this.tolerance = goldenTolerance});

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (withinGoldenTolerance(result, tolerance)) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
