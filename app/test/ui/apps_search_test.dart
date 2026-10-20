import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/ui/pages/apps_page.dart';
import 'package:gamer_launcher/ui/widgets/app_filter.dart';

import '../support/harness.dart';

Finder get _field => find.descendant(
  of: find.byType(AppsPage),
  matching: find.byType(EditableText),
);

Finder _tileIn(String name) => find.descendant(
  of: find.byType(AppGrid),
  matching: find.text(name),
);

Future<LauncherHarness> _openApps(WidgetTester tester) async {
  final h = await pumpLauncher(tester);
  await h.pressAndSettle(tester, GamepadAction.tabNext);
  return h;
}

void main() {
  testWidgets('the apps page has a filter that narrows the grid', (
    tester,
  ) async {
    await _openApps(tester);

    await tester.enterText(_field, 'spo');
    await tester.pumpAndSettle();

    expect(_tileIn('Spotify'), findsOneWidget);
    expect(_tileIn('Chrome'), findsNothing);

    await tester.enterText(_field, '');
    await tester.pumpAndSettle();
    expect(_tileIn('Chrome'), findsOneWidget);
  });

  testWidgets('typing with an app focused goes to the filter', (
    tester,
  ) async {
    final h = await _openApps(tester);
    await h.pressAndSettle(tester, GamepadAction.confirm);
    expect(hasFocus(tester, _tileIn('Chrome')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pumpAndSettle();

    expect(tester.widget<EditableText>(_field).controller.text, 'p');
    expect(_tileIn('Spotify'), findsOneWidget);
    expect(_tileIn('Chrome'), findsNothing);
  });

  testWidgets('submitting the filter opens the first app found', (
    tester,
  ) async {
    final h = await _openApps(tester);
    await tester.enterText(_field, 'disc');
    await tester.pumpAndSettle();

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(h.backend.calls, contains('launchApp(discord.desktop)'));
  });

  testWidgets('the menu still enters on the first app, not the field', (
    tester,
  ) async {
    final h = await _openApps(tester);

    await h.pressAndSettle(tester, GamepadAction.right);

    expect(hasFocus(tester, _tileIn('Chrome')), isTrue);
  });

  testWidgets('a filter without matches says so', (tester) async {
    await _openApps(tester);

    await tester.enterText(_field, 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text(noAppsFoundText), findsOneWidget);
  });

  testWidgets('B from the filter goes back to the menu', (tester) async {
    final h = await _openApps(tester);
    await tester.tap(_field);
    await tester.pumpAndSettle();

    await h.pressAndSettle(tester, GamepadAction.back);

    expect(hasFocus(tester, find.text('Aplicativos').first), isTrue);
  });
}
