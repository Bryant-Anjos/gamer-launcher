import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/input/button_names.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';

void main() {
  group('effective layout', () {
    test('automatic follows the detected controller', () {
      expect(
        effectiveLayout(
          LauncherButtonLayout.auto,
          LauncherButtonLayout.nintendo,
        ),
        PadLayout.nintendo,
      );
      expect(
        effectiveLayout(LauncherButtonLayout.auto, LauncherButtonLayout.xbox),
        PadLayout.xbox,
      );
    });

    test('a forced layout ignores the detected controller', () {
      expect(
        effectiveLayout(
          LauncherButtonLayout.xbox,
          LauncherButtonLayout.nintendo,
        ),
        PadLayout.xbox,
      );
      expect(
        effectiveLayout(
          LauncherButtonLayout.nintendo,
          LauncherButtonLayout.xbox,
        ),
        PadLayout.nintendo,
      );
    });

    test('a detection that says auto counts as xbox', () {
      expect(
        effectiveLayout(LauncherButtonLayout.auto, LauncherButtonLayout.auto),
        PadLayout.xbox,
      );
    });
  });

  group('button names', () {
    test(
      'xbox confirms with A at the bottom and goes back with B at the right',
      () {
        expect(
          buttonFor(PadRole.confirm, PadLayout.xbox),
          const PadButtonName('A', FacePosition.bottom),
        );
        expect(
          buttonFor(PadRole.back, PadLayout.xbox),
          const PadButtonName('B', FacePosition.right),
        );
        expect(
          buttonFor(PadRole.search, PadLayout.xbox),
          const PadButtonName('Y', FacePosition.top),
        );
      },
    );

    test(
      'nintendo confirms with A at the right and goes back with B below',
      () {
        expect(
          buttonFor(PadRole.confirm, PadLayout.nintendo),
          const PadButtonName('A', FacePosition.right),
        );
        expect(
          buttonFor(PadRole.back, PadLayout.nintendo),
          const PadButtonName('B', FacePosition.bottom),
        );
        expect(
          buttonFor(PadRole.search, PadLayout.nintendo),
          const PadButtonName('Y', FacePosition.left),
        );
      },
    );

    test('X (secondary) is left on xbox and on top on nintendo', () {
      expect(
        buttonFor(PadRole.secondary, PadLayout.xbox),
        const PadButtonName('X', FacePosition.left),
      );
      expect(
        buttonFor(PadRole.secondary, PadLayout.nintendo),
        const PadButtonName('X', FacePosition.top),
      );
    });

    test('each position has a spoken name', () {
      expect(FacePosition.bottom.spoken, 'botão de baixo');
      expect(FacePosition.right.spoken, 'botão da direita');
      expect(FacePosition.top.spoken, 'botão de cima');
      expect(FacePosition.left.spoken, 'botão da esquerda');
    });
  });
}
