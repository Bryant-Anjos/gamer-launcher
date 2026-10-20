import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/ui/home/favorites_picker.dart';
import 'package:gamer_launcher/ui/home/greeting_header.dart';
import 'package:gamer_launcher/ui/search/search_overlay.dart';
import 'package:gamer_launcher/ui/search/search_results.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

Finder get _searchInput => find.descendant(
  of: find.byType(SearchOverlay),
  matching: find.byType(EditableText),
);

Future<LauncherHarness> _openSearch(
  WidgetTester tester, {
  FakeBackend? backend,
}) async {
  final h = await pumpLauncher(tester, backend: backend);
  await h.pressAndSettle(tester, GamepadAction.search);
  return h;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_searchInput, text);
  await tester.pumpAndSettle();
}

Finder _result(String title) => find.descendant(
  of: find.byType(SearchResultsList),
  matching: find.text(title),
);

void main() {
  group('global search', () {
    testWidgets('Y opens the search from any section, ready to type', (
      tester,
    ) async {
      final h = await pumpLauncher(tester);
      await h.pressAndSettle(tester, GamepadAction.tabNext);

      await h.pressAndSettle(tester, GamepadAction.search);

      expect(find.byType(SearchOverlay), findsOneWidget);
      expect(
        tester.widget<EditableText>(_searchInput).focusNode.hasPrimaryFocus,
        isTrue,
      );
      expect(h.backend.calls, contains('prepareSearch'));
      expect(find.text(searchEmptyText), findsOneWidget);
    });

    testWidgets('typing lists apps, files and settings', (tester) async {
      await _openSearch(tester);

      await _type(tester, 'a');

      expect(_result('Arquivos'), findsOneWidget);
      expect(_result('granspace'), findsOneWidget);
      expect(_result('Papel de parede'), findsOneWidget);
    });

    testWidgets('Enter opens the first result; an app opens as an app', (
      tester,
    ) async {
      final h = await _openSearch(tester);
      await _type(tester, 'spot');

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(h.backend.calls, contains('launchApp(spotify.desktop)'));
      expect(find.byType(SearchOverlay), findsNothing);
    });

    testWidgets('down goes to the results and A opens the focused one', (
      tester,
    ) async {
      final h = await _openSearch(tester);
      await _type(tester, 'bluetooth');

      await h.pressAndSettle(tester, GamepadAction.down);
      expect(hasFocus(tester, _result('Bluetooth')), isTrue);
      await h.pressAndSettle(tester, GamepadAction.confirm);

      expect(h.backend.calls, contains('openSearchResult(setting:bluetooth)'));
    });

    testWidgets('the arrow key also leaves the field for the results', (
      tester,
    ) async {
      await _openSearch(tester);
      await _type(tester, 'bluetooth');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(hasFocus(tester, _result('Bluetooth')), isTrue);
    });

    testWidgets('A in the field opens the first result', (tester) async {
      final h = await _openSearch(tester);
      await _type(tester, 'granspace');

      await h.pressAndSettle(tester, GamepadAction.confirm);

      expect(
        h.backend.calls,
        contains('openSearchResult(file:/home/b/Projetos/granspace)'),
      );
    });

    testWidgets('nothing found says so', (tester) async {
      await _openSearch(tester);

      await _type(tester, 'zzzz');

      expect(find.text(searchNothingFound('zzzz')), findsOneWidget);
    });

    testWidgets('B closes the search', (tester) async {
      final h = await _openSearch(tester);

      await h.pressAndSettle(tester, GamepadAction.back);

      expect(find.byType(SearchOverlay), findsNothing);
    });

    testWidgets('a result that does not open becomes a message', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..failures['openSearchResult'] = 'cosmic-settings não encontrado';
      final h = await _openSearch(tester, backend: backend);
      await _type(tester, 'wi-fi');

      await h.pressAndSettle(tester, GamepadAction.confirm);

      expect(
        find.text(
          'Não foi possível abrir Wi-Fi: cosmic-settings não encontrado',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the home search bar opens the search when activated', (
      tester,
    ) async {
      await pumpLauncher(tester);

      await tester.tap(find.text(searchHint));
      await tester.pumpAndSettle();

      expect(find.byType(SearchOverlay), findsOneWidget);
    });

    testWidgets('typing on the focused home search bar starts the search', (
      tester,
    ) async {
      await pumpLauncher(tester);
      Focus.of(tester.element(find.text(searchHint))).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();

      expect(find.byType(SearchOverlay), findsOneWidget);
      expect(tester.widget<EditableText>(_searchInput).controller.text, 's');
    });
  });

  group('favorites picker filter', () {
    Future<void> openPicker(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
    }

    Finder pickerInput() => find.descendant(
      of: find.byType(FavoritesPicker),
      matching: find.byType(EditableText),
    );

    testWidgets('typing filters the apps by name', (tester) async {
      await pumpLauncher(tester);
      await openPicker(tester);
      expect(find.byType(PickerTile), findsNWidgets(6));

      await tester.enterText(pickerInput(), 'spo');
      await tester.pumpAndSettle();

      expect(find.byType(PickerTile), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PickerTile),
          matching: find.text('Spotify'),
        ),
        findsOneWidget,
      );

      await tester.enterText(pickerInput(), '');
      await tester.pumpAndSettle();
      expect(find.byType(PickerTile), findsNWidgets(6));
    });

    testWidgets('typing with an app focused goes to the filter', (
      tester,
    ) async {
      await pumpLauncher(tester);
      await openPicker(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();

      expect(tester.widget<EditableText>(pickerInput()).controller.text, 'p');
      expect(find.byType(PickerTile), findsOneWidget);
    });

    testWidgets('a filter without matches says so', (tester) async {
      await pumpLauncher(tester);
      await openPicker(tester);

      await tester.enterText(pickerInput(), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text(noAppsFoundText), findsOneWidget);
    });
  });
}
