import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

/// Capturas das telas sobrepostas e de Configurações, para conferir que
/// seguem o mesmo desenho da tela inicial.
void main() {
  setUpAll(loadLauncherFonts);

  Future<void> expectScreen(String name) =>
      expectLater(find.byType(MaterialApp), matchesGoldenFile('$name.png'));

  testWidgets('power menu', (tester) async {
    await pumpLauncher(tester);
    await tester.tap(find.text('Energia'));
    await tester.pumpAndSettle();

    await expectScreen('power_menu');
  });

  testWidgets('power confirmation', (tester) async {
    await pumpLauncher(tester);
    await tester.tap(find.text('Energia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desligar'));
    await tester.pumpAndSettle();

    await expectScreen('power_confirm');
  });

  testWidgets('quick controls overlay', (tester) async {
    final h = await pumpLauncher(
      tester,
      backend: FakeBackend(
        pairedDevices: const [
          PairedDevice(
            address: 'AA:01',
            name: 'Pro Controller',
            connected: true,
          ),
          PairedDevice(address: 'AA:02', name: 'Fone JBL', connected: false),
        ],
      ),
    );
    await h.pressAndSettle(tester, GamepadAction.quickControls);

    await expectScreen('quick_controls');
  });

  testWidgets('favorites picker', (tester) async {
    await pumpLauncher(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await expectScreen('favorites_picker');
  });

  testWidgets('search with results', (tester) async {
    final h = await pumpLauncher(tester);
    await h.pressAndSettle(tester, GamepadAction.search);
    await tester.enterText(find.byType(EditableText), 'a');
    await tester.pumpAndSettle();

    await expectScreen('search');
  });

  testWidgets('apps with filter', (tester) async {
    final h = await pumpLauncher(tester);
    await h.pressAndSettle(tester, GamepadAction.tabNext);
    await h.pressAndSettle(tester, GamepadAction.right);

    await expectScreen('apps');
  });

  testWidgets('settings', (tester) async {
    await pumpLauncher(tester);
    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    await expectScreen('settings');
  });
}
