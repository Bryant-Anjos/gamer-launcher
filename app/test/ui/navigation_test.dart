import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/ui/power/power_menu.dart';

import '../support/harness.dart';

/// O item da navegação lateral com esse rótulo (o texto pode se repetir no
/// título da página).
Finder _navItem(String label) => find.text(label).first;

Future<void> _focus(WidgetTester tester, Finder finder) async {
  Focus.of(tester.element(finder)).requestFocus();
  await tester.pumpAndSettle();
}

void main() {
  group('navigation follows the focus', () {
    testWidgets('moving down the menu opens each section without A', (
      tester,
    ) async {
      final h = await pumpLauncher(tester);
      await _focus(tester, _navItem('Início'));

      await h.pressAndSettle(tester, GamepadAction.down);

      expect(find.text('6 instalados'), findsOneWidget);
      expect(hasFocus(tester, _navItem('Aplicativos')), isTrue);
    });

    testWidgets('the arrow keys do the same', (tester) async {
      await pumpLauncher(tester);
      await _focus(tester, _navItem('Início'));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(find.text('6 instalados'), findsOneWidget);
    });

    testWidgets('passing over Energia does not open the power menu', (
      tester,
    ) async {
      final h = await pumpLauncher(tester);
      await _focus(tester, _navItem('Configurações'));

      await h.pressAndSettle(tester, GamepadAction.down);

      expect(hasFocus(tester, find.text('Energia')), isTrue);
      expect(find.byType(PowerMenu), findsNothing);
      await h.pressAndSettle(tester, GamepadAction.confirm);
      expect(find.byType(PowerMenu), findsOneWidget);
    });
  });

  group('entering the content', () {
    testWidgets('A on a menu item focuses the first item of the page', (
      tester,
    ) async {
      final h = await pumpLauncher(tester);
      await _focus(tester, _navItem('Início'));
      await h.pressAndSettle(tester, GamepadAction.down);

      await h.pressAndSettle(tester, GamepadAction.confirm);

      expect(hasFocus(tester, find.text('Chrome')), isTrue);
    });

    testWidgets('right from Início lands on Continuar, not the search', (
      tester,
    ) async {
      final h = await pumpLauncher(tester);
      await _focus(tester, _navItem('Início'));

      await h.pressAndSettle(tester, GamepadAction.right);

      expect(hasFocus(tester, find.text('Continuar')), isTrue);
    });

    testWidgets('the right arrow key also lands on Continuar', (tester) async {
      await pumpLauncher(tester);
      await _focus(tester, _navItem('Início'));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(hasFocus(tester, find.text('Continuar')), isTrue);
    });

    testWidgets('right from Configurações lands on its first option', (
      tester,
    ) async {
      final h = await pumpLauncher(tester);
      await _focus(tester, _navItem('Configurações'));

      await h.pressAndSettle(tester, GamepadAction.right);

      expect(hasFocus(tester, find.text('Claro')), isTrue);
    });

    testWidgets('the search is still reached going up from the cards', (
      tester,
    ) async {
      final h = await pumpLauncher(tester);
      await _focus(tester, _navItem('Início'));
      await h.pressAndSettle(tester, GamepadAction.right);

      await h.pressAndSettle(tester, GamepadAction.up);

      expect(
        hasFocus(
          tester,
          find.text('Pesquisar aplicativos, arquivos, configurações...'),
        ),
        isTrue,
      );
    });
  });

  group('B goes back to the menu', () {
    testWidgets('from the content, B focuses the current section item', (
      tester,
    ) async {
      final h = await pumpLauncher(tester);
      await _focus(tester, _navItem('Aplicativos'));
      await h.pressAndSettle(tester, GamepadAction.confirm);
      expect(hasFocus(tester, find.text('Chrome')), isTrue);

      await h.pressAndSettle(tester, GamepadAction.back);

      expect(hasFocus(tester, _navItem('Aplicativos')), isTrue);
      expect(find.text('6 instalados'), findsOneWidget);
    });

    testWidgets('Esc does the same from the keyboard', (tester) async {
      final h = await pumpLauncher(tester);
      await _focus(tester, _navItem('Início'));
      await h.pressAndSettle(tester, GamepadAction.right);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(hasFocus(tester, _navItem('Início')), isTrue);
    });

    testWidgets('with an overlay open, B only closes the overlay', (
      tester,
    ) async {
      final h = await pumpLauncher(tester);
      await _focus(tester, _navItem('Configurações'));
      await h.pressAndSettle(tester, GamepadAction.down);
      await h.pressAndSettle(tester, GamepadAction.confirm);
      expect(find.byType(PowerMenu), findsOneWidget);

      await h.pressAndSettle(tester, GamepadAction.back);

      expect(find.byType(PowerMenu), findsNothing);
    });
  });
}
