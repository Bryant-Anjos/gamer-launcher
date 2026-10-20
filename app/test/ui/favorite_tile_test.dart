import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/catalog.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/home/favorite_tile.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';
import 'package:gamer_launcher/ui/widgets/icon_color.dart';

const _spotify = Color(0xFF1DB954);
const _tileSize = Size(320, 210);

Widget _themed(
  Widget child, {
  Brightness brightness = Brightness.dark,
  bool reduceAnimations = false,
}) => MaterialApp(
  theme: buildLauncherTheme(brightness),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceAnimations),
    child: Scaffold(
      body: Center(
        child: SizedBox.fromSize(size: _tileSize, child: child),
      ),
    ),
  ),
);

FavoriteTile _tile({Color color = _spotify, bool isMoving = false}) =>
    FavoriteTile(
      label: 'Spotify',
      color: color,
      icon: const Icon(Icons.music_note_rounded),
      isMoving: isMoving,
      onActivate: () {},
    );

LinearGradient _gradient(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).gradient is LinearGradient,
    ),
  );
  return (box.decoration as BoxDecoration).gradient! as LinearGradient;
}

void main() {
  for (final brightness in Brightness.values) {
    group('FavoriteTile in the ${brightness.name} theme', () {
      testWidgets('has a diagonal gradient in the color of the icon', (
        tester,
      ) async {
        await tester.pumpWidget(_themed(_tile(), brightness: brightness));

        final gradient = _gradient(tester);
        expect(gradient.colors, tileGradient(_spotify));
        expect(gradient.begin, Alignment.topLeft);
        expect(gradient.end, Alignment.bottomRight);
      });

      testWidgets('shows the name in white on the dark band', (tester) async {
        await tester.pumpWidget(_themed(_tile(), brightness: brightness));

        final text = tester.widget<Text>(find.text('Spotify'));
        expect(text.style?.color, Colors.white);
        final band = tester.widget<ColoredBox>(
          find
              .ancestor(
                of: find.text('Spotify'),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(band.color, tileCaptionColor);
      });
    });
  }

  testWidgets('keeps the icon in the middle', (tester) async {
    await tester.pumpWidget(_themed(_tile()));

    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
  });

  testWidgets('grows and shows the ring when focused', (tester) async {
    await tester.pumpWidget(_themed(_tile()));
    Focus.of(tester.element(find.byType(AnimatedScale))).requestFocus();
    await tester.pumpAndSettle();

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      greaterThan(1),
    );
  });

  testWidgets('while moving shows the badge and says so', (tester) async {
    await tester.pumpWidget(_themed(_tile(isMoving: true)));

    expect(find.byIcon(Icons.open_with_rounded), findsOneWidget);
    expect(
      tester.widget<FocusTile>(find.byType(FocusTile)).semanticLabel,
      'Spotify, movendo',
    );
  });

  testWidgets('without moving there is no badge', (tester) async {
    await tester.pumpWidget(_themed(_tile()));

    expect(find.byIcon(Icons.open_with_rounded), findsNothing);
  });

  testWidgets('a new color fades in', (tester) async {
    await tester.pumpWidget(_themed(_tile()));
    await tester.pumpWidget(_themed(_tile(color: Colors.red)));
    await tester.pump(const Duration(milliseconds: 1));

    expect(_gradient(tester).colors, isNot(tileGradient(Colors.red)));
    await tester.pumpAndSettle();
    expect(_gradient(tester).colors, tileGradient(Colors.red));
  });

  testWidgets('with reduced animations the color changes at once', (
    tester,
  ) async {
    await tester.pumpWidget(_themed(_tile(), reduceAnimations: true));
    await tester.pumpWidget(
      _themed(_tile(color: Colors.red), reduceAnimations: true),
    );
    await tester.pump();

    expect(_gradient(tester).colors, tileGradient(Colors.red));
  });

  testWidgets('the drag image has the same face, with the badge', (
    tester,
  ) async {
    const app = AppInfo(id: 'spotify.desktop', name: 'Spotify', categories: []);
    await tester.pumpWidget(_themed(const FavoriteDragImage(app)));

    expect(
      _gradient(tester).colors,
      tileGradient(fallbackIconColor('Spotify')),
    );
    expect(find.text('Spotify'), findsOneWidget);
    expect(find.byIcon(Icons.open_with_rounded), findsOneWidget);
  });
}
