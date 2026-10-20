import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/ui/widgets/icon_color.dart';
import 'package:gamer_launcher/ui/widgets/icon_color_cache.dart';

const _red = Color(0xFFD03030);
const _iconSide = 256;

/// PNG de um quadrado vermelho com borda transparente, grande o bastante para
/// a leitura ter que reduzir antes de amostrar.
Future<List<int>> _redPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const inset = _iconSide / 8;
  canvas.drawRect(
    const Rect.fromLTRB(inset, inset, _iconSide - inset, _iconSide - inset),
    Paint()..color = _red,
  );
  final image = await recorder.endRecording().toImage(_iconSide, _iconSide);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

const _blueSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<rect x="4" y="4" width="40" height="40" fill="#2F6BD0"/></svg>';

Widget _tint(IconColorCache cache, {String? path, String name = 'Spotify'}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: IconTint(
        name: name,
        iconPath: path,
        cache: cache,
        builder: (context, color) => ColoredBox(color: color),
      ),
    );

Color _shown(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.byType(ColoredBox)).color;

void main() {
  group('loadIconColor', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('icon-color'));
    tearDown(() => dir.deleteSync(recursive: true));

    testWidgets('reads the main color of a png', (tester) async {
      final file = File('${dir.path}/app.png');
      final color = await tester.runAsync(() async {
        file.writeAsBytesSync(await _redPng());
        return loadIconColor(file.path);
      });

      expect(color?.toARGB32(), _red.toARGB32());
    });

    testWidgets('reads the main color of an svg', (tester) async {
      final file = File('${dir.path}/app.svg')..writeAsStringSync(_blueSvg);
      final color = await tester.runAsync(() => loadIconColor(file.path));

      expect(color?.toARGB32(), const Color(0xFF2F6BD0).toARGB32());
    });

    testWidgets('a missing or broken file gives no color', (tester) async {
      final broken = File('${dir.path}/broken.png')..writeAsStringSync('x');
      final badSvg = File('${dir.path}/bad.svg')..writeAsStringSync('<svg');

      final results = await tester.runAsync(
        () => Future.wait([
          loadIconColor('${dir.path}/missing.png'),
          loadIconColor(broken.path),
          loadIconColor(badSvg.path),
        ]),
      );

      expect(results, [null, null, null]);
    });

    testWidgets('a huge file is not decoded', (tester) async {
      final huge = File('${dir.path}/huge.png')
        ..writeAsBytesSync(List.filled(maxIconBytes + 1, 0));

      expect(await tester.runAsync(() => loadIconColor(huge.path)), isNull);
    });
  });

  group('IconColorCache', () {
    test('loads each icon once and remembers it, even without color', () async {
      final calls = <String>[];
      final cache = IconColorCache(
        loader: (path) async {
          calls.add(path);
          return path == '/a.png' ? _red : null;
        },
      );

      expect(cache.contains('/a.png'), isFalse);
      final results = await Future.wait([
        cache.resolve('/a.png'),
        cache.resolve('/a.png'),
        cache.resolve('/gray.png'),
      ]);
      await cache.resolve('/gray.png');

      expect(results, [_red, _red, null]);
      expect(calls, ['/a.png', '/gray.png']);
      expect(cache.contains('/gray.png'), isTrue);
      expect(cache.peek('/a.png'), _red);
      expect(cache.peek('/gray.png'), isNull);
    });
  });

  group('IconTint', () {
    testWidgets('without an icon uses the stable color of the name', (
      tester,
    ) async {
      final cache = IconColorCache(loader: (_) async => fail('no icon'));
      await tester.pumpWidget(_tint(cache));

      expect(_shown(tester), fallbackIconColor('Spotify'));
    });

    testWidgets('starts with the fallback and switches when the color comes', (
      tester,
    ) async {
      final pending = Completer<Color?>();
      final cache = IconColorCache(loader: (_) => pending.future);
      await tester.pumpWidget(_tint(cache, path: '/a.png'));

      expect(_shown(tester), fallbackIconColor('Spotify'));

      pending.complete(_red);
      await tester.pumpAndSettle();
      expect(_shown(tester), _red);
    });

    testWidgets('an icon already read shows its color on the first frame', (
      tester,
    ) async {
      final cache = IconColorCache(loader: (_) async => _red);
      await cache.resolve('/a.png');
      await tester.pumpWidget(_tint(cache, path: '/a.png'));

      expect(_shown(tester), _red);
    });

    testWidgets('an icon without color keeps the fallback', (tester) async {
      final cache = IconColorCache(loader: (_) async => null);
      await tester.pumpWidget(_tint(cache, path: '/gray.png'));
      await tester.pump();

      expect(_shown(tester), fallbackIconColor('Spotify'));
    });

    testWidgets('follows a change of icon', (tester) async {
      const blue = Color(0xFF2F6BD0);
      final cache = IconColorCache(
        loader: (path) async => path == '/a.png' ? _red : blue,
      );
      await tester.pumpWidget(_tint(cache, path: '/a.png'));
      await tester.pump();
      await tester.pumpWidget(_tint(cache, path: '/b.png'));
      await tester.pump();

      expect(_shown(tester), blue);
    });

    testWidgets('a late color for an old icon is ignored', (tester) async {
      final slow = Completer<Color?>();
      final cache = IconColorCache(
        loader: (path) => path == '/a.png' ? slow.future : Future.value(null),
      );
      await tester.pumpWidget(_tint(cache, path: '/a.png'));
      await tester.pumpWidget(_tint(cache, path: '/b.png'));
      await tester.pump();
      slow.complete(_red);
      await tester.pump();

      expect(_shown(tester), fallbackIconColor('Spotify'));
    });
  });
}
