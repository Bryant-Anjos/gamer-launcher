import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/tolerant_golden_comparator.dart';

const _side = 100;
const _totalPixels = _side * _side;

/// PNG branco de 100x100 com os pixels dados pintados de preto.
Future<Uint8List> _png(Iterable<int> blackPixels) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final white = Paint()..color = Colors.white;
  final black = Paint()..color = Colors.black;
  canvas.drawRect(
    Rect.fromLTWH(0, 0, _side.toDouble(), _side.toDouble()),
    white,
  );
  for (final index in blackPixels) {
    final x = (index % _side).toDouble();
    final y = (index ~/ _side).toDouble();
    canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), black);
  }
  final image = await recorder.endRecording().toImage(_side, _side);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  group('withinGoldenTolerance', () {
    test('accepts an exact match', () {
      final result = ComparisonResult(passed: true, diffPercent: 0);

      expect(withinGoldenTolerance(result), isTrue);
    });

    test('accepts rendering noise below the tolerance', () {
      // o que a CI mediu: 0,03% de pixels diferentes
      final result = ComparisonResult(passed: false, diffPercent: 0.0003);

      expect(withinGoldenTolerance(result), isTrue);
    });

    test('accepts exactly the tolerance', () {
      final result = ComparisonResult(
        passed: false,
        diffPercent: goldenTolerance,
      );

      expect(withinGoldenTolerance(result), isTrue);
    });

    test('rejects a real visual change above the tolerance', () {
      final result = ComparisonResult(passed: false, diffPercent: 0.01);

      expect(withinGoldenTolerance(result), isFalse);
    });

    test('the tolerance stays strict (at most 0.1% of the pixels)', () {
      expect(goldenTolerance, lessThanOrEqualTo(0.001));
    });
  });

  group('TolerantGoldenComparator', () {
    late Directory dir;
    late TolerantGoldenComparator comparator;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('golden_tolerance_');
      comparator = TolerantGoldenComparator(dir.uri.resolve('some_test.dart'));
    });

    tearDown(() => dir.deleteSync(recursive: true));

    Future<void> saveGolden(Uint8List bytes) async =>
        File('${dir.path}/ref.png').writeAsBytes(bytes);

    testWidgets('passes an identical image', (tester) async {
      await tester.runAsync(() async {
        final reference = await _png(const []);
        await saveGolden(reference);

        expect(
          await comparator.compare(reference, Uri.parse('ref.png')),
          isTrue,
        );
      });
    });

    testWidgets('passes a few differing pixels (noise)', (tester) async {
      await tester.runAsync(() async {
        await saveGolden(await _png(const []));
        // 5 de 10.000 pixels = 0,05%
        final noisy = await _png(List.generate(5, (i) => i * 7));

        expect(await comparator.compare(noisy, Uri.parse('ref.png')), isTrue);
      });
    });

    testWidgets('fails a large difference', (tester) async {
      await tester.runAsync(() async {
        await saveGolden(await _png(const []));
        // 500 de 10.000 pixels = 5%
        final changed = await _png(List.generate(500, (i) => i * 3));

        await expectLater(
          comparator.compare(changed, Uri.parse('ref.png')),
          throwsA(isA<FlutterError>()),
        );
      });
    });

    testWidgets('a missing golden is still an error', (tester) async {
      await tester.runAsync(() async {
        final image = await _png(const []);

        await expectLater(
          comparator.compare(image, Uri.parse('nao_existe.png')),
          throwsA(anything),
        );
      });
    });

    test('the noise case really is below the tolerance', () {
      expect(5 / _totalPixels, lessThan(goldenTolerance));
      expect(500 / _totalPixels, greaterThan(goldenTolerance));
    });
  });
}
