import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/ui/home/favorites_panel.dart';
import 'package:gamer_launcher/ui/home/featured_cards.dart';

import '../support/harness.dart';

Finder _tile(String name) =>
    find.byWidgetPredicate((w) => w is FavoriteTile && w.label == name);

/// Ordem dos favoritos na tela, da esquerda para a direita e de cima para
/// baixo.
List<String> _shownOrder(WidgetTester tester) {
  final tiles = tester
      .widgetList<FavoriteTile>(find.byType(FavoriteTile))
      .where((t) => t.label != addFavoriteLabel)
      .toList();
  final positioned =
      [for (final t in tiles) (t.label, tester.getRect(find.byWidget(t)))]
        ..sort((a, b) {
          final row = a.$2.top.compareTo(b.$2.top);
          return row != 0 ? row : a.$2.left.compareTo(b.$2.left);
        });
  return [for (final (label, _) in positioned) label];
}

Finder _inside(String name) => find
    .descendant(of: _tile(name), matching: find.byType(AnimatedScale))
    .first;

bool _tileHasFocus(WidgetTester tester, String name) =>
    Focus.of(tester.element(_inside(name))).hasPrimaryFocus;

Future<void> _focusTile(WidgetTester tester, String name) async {
  Focus.of(
    tester.element(
      find
          .descendant(of: _tile(name), matching: find.byType(AnimatedScale))
          .first,
    ),
  ).requestFocus();
  await tester.pumpAndSettle();
}

void main() {
  group('layout', () {
    testWidgets('recents sit below the system panel, on the right', (
      tester,
    ) async {
      await pumpLauncher(tester);

      final system = tester.getRect(find.text('Sistema'));
      final recents = tester.getRect(find.text('Recentes'));
      expect(recents.top, greaterThan(system.top));
      expect(recents.left, closeTo(system.left, 1));
    });

    testWidgets('favorite tiles have the size of the featured cards', (
      tester,
    ) async {
      await pumpLauncher(tester);

      final card = tester.getSize(find.byType(FeaturedCard).first);
      final tile = tester.getSize(_tile('VS Code'));
      expect(tile.width, closeTo(card.width, 1));
      expect(tile.height, closeTo(card.height, 1));
      expect(_tile(addFavoriteLabel), findsOneWidget);
    });

    testWidgets('the layout also fits an ultrawide screen', (tester) async {
      await pumpLauncher(tester, size: const Size(2560, 1080));

      expect(tester.takeException(), isNull);
      final card = tester.getSize(find.byType(FeaturedCard).first);
      expect(tester.getSize(_tile('VS Code')).width, closeTo(card.width, 1));
    });

    testWidgets('A on a favorite opens the app', (tester) async {
      final h = await pumpLauncher(tester);
      await _focusTile(tester, 'Chrome');

      await h.pressAndSettle(tester, GamepadAction.confirm);

      expect(h.backend.calls, contains('launchApp(chrome.desktop)'));
    });
  });

  group('reordering', () {
    testWidgets('X starts moving, the d-pad moves and A saves the order', (
      tester,
    ) async {
      final h = await pumpLauncher(tester);
      await _focusTile(tester, 'VS Code');

      await h.pressAndSettle(tester, GamepadAction.secondary);
      expect(find.text('A confirma'), findsOneWidget);
      await h.pressAndSettle(tester, GamepadAction.right);
      expect(_shownOrder(tester).take(2), ['Chrome', 'VS Code']);
      await h.pressAndSettle(tester, GamepadAction.confirm);

      expect(h.backend.saved.last.favorites.take(2), [
        'chrome.desktop',
        'code.desktop',
      ]);
      expect(h.backend.calls, isNot(contains('launchApp(code.desktop)')));
      expect(_tileHasFocus(tester, 'VS Code'), isTrue);
    });

    testWidgets('down moves a whole row', (tester) async {
      final h = await pumpLauncher(tester);
      await _focusTile(tester, 'VS Code');

      await h.pressAndSettle(tester, GamepadAction.secondary);
      await h.pressAndSettle(tester, GamepadAction.down);
      await h.pressAndSettle(tester, GamepadAction.confirm);

      expect(h.backend.saved.last.favorites.last, 'code.desktop');
    });

    testWidgets('B cancels: nothing is saved and the focus stays', (
      tester,
    ) async {
      final h = await pumpLauncher(tester);
      await _focusTile(tester, 'VS Code');
      final before = _shownOrder(tester);

      await h.pressAndSettle(tester, GamepadAction.secondary);
      await h.pressAndSettle(tester, GamepadAction.right);
      await h.pressAndSettle(tester, GamepadAction.back);

      expect(_shownOrder(tester), before);
      expect(h.backend.saved, isEmpty);
      expect(_tileHasFocus(tester, 'VS Code'), isTrue);
    });

    testWidgets('the keyboard uses M, the arrows and Enter', (tester) async {
      final h = await pumpLauncher(tester);
      await _focusTile(tester, 'VS Code');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(h.backend.saved.last.favorites.take(2), [
        'chrome.desktop',
        'code.desktop',
      ]);
    });

    testWidgets('Esc cancels the move instead of leaving to the menu', (
      tester,
    ) async {
      final h = await pumpLauncher(tester);
      await _focusTile(tester, 'VS Code');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(h.backend.saved, isEmpty);
      expect(_tileHasFocus(tester, 'VS Code'), isTrue);
    });

    testWidgets('a favorite can be dragged with the mouse', (tester) async {
      final h = await pumpLauncher(tester);

      await tester.drag(
        _tile('VS Code'),
        tester.getCenter(_tile('Arquivos')) -
            tester.getCenter(_tile('VS Code')),
      );
      await tester.pumpAndSettle();

      expect(h.backend.saved.last.favorites.indexOf('code.desktop'), 2);
    });

    testWidgets('the hint shows X to move when a favorite is focused', (
      tester,
    ) async {
      await pumpLauncher(tester);
      expect(find.text('X move'), findsNothing);

      await _focusTile(tester, 'Chrome');

      expect(find.text('X move'), findsOneWidget);
    });
  });
}
