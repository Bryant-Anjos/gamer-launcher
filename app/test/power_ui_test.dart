import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/ui/power/power_menu.dart';
import 'package:gamer_launcher/ui/shell/top_bar.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

bool _autostartIsOn(WidgetTester tester) {
  final row = find.ancestor(
    of: find.text('Iniciar com o sistema'),
    matching: find.byType(Row),
  );
  final toggle = find.descendant(of: row.first, matching: find.byType(Switch));
  return tester.widget<Switch>(toggle).value;
}

Finder _inBattery(String text) => find.descendant(
  of: find.byType(BatteryIndicator),
  matching: find.text(text),
);

Future<LauncherHarness> _openMenu(
  WidgetTester tester, {
  FakeBackend? backend,
}) async {
  final h = await pumpLauncher(tester, backend: backend);
  await tester.tap(find.text('Energia'));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  group('battery in the top bar', () {
    testWidgets('shows the percentage', (tester) async {
      await pumpLauncher(tester);

      expect(_inBattery('80%'), findsOneWidget);
    });

    testWidgets('says when it is charging', (tester) async {
      await pumpLauncher(
        tester,
        backend: FakeBackend(
          battery: const BatteryReading(percent: 55, charging: true),
        ),
      );

      expect(_inBattery('55%'), findsOneWidget);
      expect(find.bySemanticsLabel('Bateria carregando'), findsOneWidget);
    });

    testWidgets('is hidden on a computer without battery', (tester) async {
      await pumpLauncher(tester, backend: FakeBackend(battery: null));

      expect(find.byType(BatteryIndicator), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Bateria')), findsNothing);
    });

    testWidgets('a low battery is called out', (tester) async {
      await pumpLauncher(
        tester,
        backend: FakeBackend(
          battery: const BatteryReading(percent: 12, charging: false),
        ),
      );

      expect(find.bySemanticsLabel('Bateria fraca'), findsOneWidget);
    });
  });

  group('power menu', () {
    testWidgets('opens from the navigation and lists every option', (
      tester,
    ) async {
      await _openMenu(tester);

      expect(find.byType(PowerMenu), findsOneWidget);
      for (final label in [
        'Suspender',
        'Reiniciar',
        'Desligar',
        'Encerrar sessão',
        'Fechar o launcher',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('the first option has the focus, for the controller', (
      tester,
    ) async {
      await _openMenu(tester);

      expect(hasFocus(tester, find.text('Suspender')), isTrue);
    });

    testWidgets('suspend runs at once and closes the menu', (tester) async {
      final h = await _openMenu(tester);

      await tester.tap(find.text('Suspender'));
      await tester.pumpAndSettle();

      expect(h.backend.calls, contains('performPowerAction(suspend)'));
      expect(find.byType(PowerMenu), findsNothing);
    });

    testWidgets('shutdown asks first, with Cancel focused', (tester) async {
      final h = await _openMenu(tester);

      await tester.tap(find.text('Desligar'));
      await tester.pumpAndSettle();

      expect(find.text('Desligar o computador?'), findsOneWidget);
      expect(hasFocus(tester, find.text('Cancelar')), isTrue);
      expect(
        h.backend.calls.where((c) => c.startsWith('performPowerAction')),
        isEmpty,
      );
    });

    testWidgets('confirming runs the action and closes the menu', (
      tester,
    ) async {
      final h = await _openMenu(tester);
      await tester.tap(find.text('Reiniciar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reiniciar'));
      await tester.pumpAndSettle();

      expect(h.backend.calls, contains('performPowerAction(reboot)'));
      expect(find.byType(PowerMenu), findsNothing);
    });

    testWidgets('cancelling goes back to the list and does nothing', (
      tester,
    ) async {
      final h = await _openMenu(tester);
      await tester.tap(find.text('Encerrar sessão'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Fechar o launcher'), findsOneWidget);
      expect(
        h.backend.calls.where((c) => c.startsWith('performPowerAction')),
        isEmpty,
      );
    });

    testWidgets('closing the launcher calls the app close', (tester) async {
      final h = await _openMenu(tester);

      await tester.tap(find.text('Fechar o launcher'));
      await tester.pumpAndSettle();

      expect(h.closes, 1);
    });

    testWidgets('B closes the menu without doing anything', (tester) async {
      final h = await _openMenu(tester);

      await h.pressAndSettle(tester, GamepadAction.back);

      expect(find.byType(PowerMenu), findsNothing);
      expect(h.closes, 0);
      expect(
        h.backend.calls.where((c) => c.startsWith('performPowerAction')),
        isEmpty,
      );
    });

    testWidgets('B on the confirmation goes back to the list first', (
      tester,
    ) async {
      final h = await _openMenu(tester);
      await tester.tap(find.text('Desligar'));
      await tester.pumpAndSettle();

      await h.pressAndSettle(tester, GamepadAction.back);

      expect(find.byType(PowerMenu), findsOneWidget);
      expect(find.text('Desligar o computador?'), findsNothing);
    });

    testWidgets('a refused action shows the reason', (tester) async {
      final backend = FakeBackend()
        ..failures['performPowerAction'] =
            'Interactive authentication required.';
      await _openMenu(tester, backend: backend);

      await tester.tap(find.text('Suspender'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Interactive authentication required.'),
        findsOneWidget,
      );
    });
  });

  group('start with the system', () {
    Future<LauncherHarness> openSettings(
      WidgetTester tester, {
      FakeBackend? backend,
    }) async {
      final h = await pumpLauncher(tester, backend: backend);
      await tester.tap(find.text('Configurações').first);
      await tester.pumpAndSettle();
      // a chave fica no fim da página: só é montada depois de rolar
      await tester.scrollUntilVisible(find.text('Iniciar com o sistema'), 200);
      return h;
    }

    testWidgets('the setting reflects what the system has', (tester) async {
      await openSettings(tester, backend: FakeBackend(autostart: true));

      final row = find.ancestor(
        of: find.text('Iniciar com o sistema'),
        matching: find.byType(Row),
      );
      final toggle = find.descendant(
        of: row.first,
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(toggle).value, isTrue);
    });

    testWidgets('toggling it asks the system and shows the new state', (
      tester,
    ) async {
      final h = await openSettings(tester);

      await tester.tap(find.text('Iniciar com o sistema'));
      await tester.pumpAndSettle();

      expect(h.backend.calls, contains('setAutostart(true)'));
      expect(_autostartIsOn(tester), isTrue);
    });

    testWidgets('a refusal puts the switch back and says why', (tester) async {
      final backend = FakeBackend()..failures['setAutostart'] = 'sem permissão';
      await openSettings(tester, backend: backend);

      await tester.tap(find.text('Iniciar com o sistema'));
      await tester.pumpAndSettle();

      expect(_autostartIsOn(tester), isFalse);
      expect(find.textContaining('sem permissão'), findsOneWidget);
    });
  });
}
