import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/input/button_names.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/ui/widgets/button_hints.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';
import '../support/samples.dart';

FakeBackend _backend({
  LauncherButtonLayout layout = LauncherButtonLayout.auto,
  LauncherButtonLayout detected = LauncherButtonLayout.xbox,
  bool sounds = false,
  bool reduceAnimations = false,
}) => FakeBackend(
  settings: sampleSettings(
    buttonLayout: layout,
    sounds: sounds,
    reduceAnimations: reduceAnimations,
  ),
  detectedLayout: detected,
);

Future<void> _openPowerMenu(WidgetTester tester) async {
  await tester.tap(find.text('Energia'));
  await tester.pumpAndSettle();
}

FacePosition _glyphFor(WidgetTester tester, String letter) => tester
    .widget<ButtonGlyph>(
      find.byWidgetPredicate((w) => w is ButtonGlyph && w.letter == letter),
    )
    .position;

Future<LauncherHarness> _openSettings(
  WidgetTester tester,
  FakeBackend backend,
) async {
  final h = await pumpLauncher(tester, backend: backend);
  await tester.tap(find.text('Configurações'));
  await tester.pumpAndSettle();
  return h;
}

Future<void> _tapSetting(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(find.text(label), 200);
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

List<String> _played(FakeBackend backend) =>
    backend.calls.where((call) => call.startsWith('playUiSound')).toList();

void main() {
  group('button hints', () {
    testWidgets('an xbox controller confirms with A at the bottom', (
      tester,
    ) async {
      await pumpLauncher(tester, backend: _backend());
      await _openPowerMenu(tester);

      expect(find.text('A escolhe'), findsOneWidget);
      expect(find.text('B fecha'), findsOneWidget);
      expect(_glyphFor(tester, 'A'), FacePosition.bottom);
      expect(_glyphFor(tester, 'B'), FacePosition.right);
    });

    testWidgets('a detected nintendo controller confirms with A at the right', (
      tester,
    ) async {
      await pumpLauncher(
        tester,
        backend: _backend(detected: LauncherButtonLayout.nintendo),
      );
      await _openPowerMenu(tester);

      expect(_glyphFor(tester, 'A'), FacePosition.right);
      expect(_glyphFor(tester, 'B'), FacePosition.bottom);
    });

    testWidgets('a forced layout wins over the detected controller', (
      tester,
    ) async {
      await pumpLauncher(
        tester,
        backend: _backend(
          layout: LauncherButtonLayout.nintendo,
          detected: LauncherButtonLayout.xbox,
        ),
      );
      await _openPowerMenu(tester);

      expect(_glyphFor(tester, 'A'), FacePosition.right);
    });

    testWidgets('the glyph says where the button is', (tester) async {
      await pumpLauncher(tester, backend: _backend());
      await _openPowerMenu(tester);

      expect(find.bySemanticsLabel('A, botão de baixo'), findsOneWidget);
    });
  });

  group('settings', () {
    testWidgets('choosing a layout saves it and applies it live', (
      tester,
    ) async {
      final backend = _backend();
      await _openSettings(tester, backend);

      await _tapSetting(tester, 'Nintendo');

      expect(backend.saved.last.buttonLayout, LauncherButtonLayout.nintendo);
      expect(backend.calls, contains('setButtonLayout(nintendo)'));
    });

    testWidgets('sounds and reduced animations are switches', (tester) async {
      final backend = _backend();
      await _openSettings(tester, backend);

      await _tapSetting(tester, 'Sons');
      expect(backend.saved.last.sounds, isTrue);

      await _tapSetting(tester, 'Reduzir animações');
      expect(backend.saved.last.reduceAnimations, isTrue);
    });
  });

  group('sounds', () {
    testWidgets('navigate, confirm and back play when sounds are on', (
      tester,
    ) async {
      final backend = _backend(sounds: true);
      final h = await pumpLauncher(tester, backend: backend);

      await h.pressAndSettle(tester, GamepadAction.down);
      await h.pressAndSettle(tester, GamepadAction.confirm);
      await h.pressAndSettle(tester, GamepadAction.back);

      expect(_played(backend), [
        'playUiSound(navigate)',
        'playUiSound(confirm)',
        'playUiSound(back)',
      ]);
    });

    testWidgets('the keyboard plays them too', (tester) async {
      final backend = _backend(sounds: true);
      await pumpLauncher(tester, backend: backend);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_played(backend), ['playUiSound(navigate)', 'playUiSound(back)']);
    });

    testWidgets('nothing plays when sounds are off', (tester) async {
      final backend = _backend();
      final h = await pumpLauncher(tester, backend: backend);

      await h.pressAndSettle(tester, GamepadAction.down);
      await h.pressAndSettle(tester, GamepadAction.confirm);

      expect(_played(backend), isEmpty);
    });
  });

  group('reduced animations', () {
    testWidgets('the focus ring stops animating', (tester) async {
      await pumpLauncher(tester, backend: _backend(reduceAnimations: true));

      final scales = tester.widgetList<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(scales, isNotEmpty);
      expect(scales.every((s) => s.duration == Duration.zero), isTrue);
    });

    testWidgets('animations stay on by default', (tester) async {
      await pumpLauncher(tester, backend: _backend());

      final scale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale).first,
      );
      expect(scale.duration, greaterThan(Duration.zero));
    });
  });
}
