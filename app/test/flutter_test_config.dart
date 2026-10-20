import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'support/tolerant_golden_comparator.dart';

/// Roda antes de cada arquivo de teste: troca o comparador de goldens pelo
/// que tolera ruído de renderização entre sistemas.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final current = goldenFileComparator;
  if (current is LocalFileComparator) {
    goldenFileComparator = TolerantGoldenComparator(
      current.basedir.resolve('golden_placeholder_test.dart'),
    );
  }
  await testMain();
}
