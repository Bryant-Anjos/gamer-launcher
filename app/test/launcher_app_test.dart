import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/ui/home/greeting_header.dart';
import 'package:gamer_launcher/ui/quick/quick_controls_panel.dart';
import 'package:gamer_launcher/ui/search/search_overlay.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';
import 'support/samples.dart';

PanelVisibility _onlyNavigation() => const PanelVisibility(
  search: false,
  quickControls: false,
  system: false,
  recents: false,
  favorites: false,
  featuredCards: false,
);

void main() {
  testWidgets('does not show a debug banner', (tester) async {
    await pumpLauncher(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.debugShowCheckedModeBanner, isFalse);
  });

  testWidgets('home shows the greeting, panels, clock and status', (
    tester,
  ) async {
    await pumpLauncher(tester);

    expect(find.text('Boa noite, Bryant'), findsOneWidget);
    expect(find.text('19:42'), findsOneWidget);
    expect(find.text('Sex, 16 de Out'), findsOneWidget);
    for (final title in ['Continuar', 'Projetos', 'Jogos', 'Músicas']) {
      expect(find.text(title), findsWidgets, reason: title);
    }
    expect(find.text('Aplicativos favoritos'), findsOneWidget);
    expect(find.text('Recentes'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
    expect(find.text('Casa_5G'), findsOneWidget);
    expect(find.text(searchHint), findsOneWidget);
    expect(find.bySemanticsLabel('Controle conectado'), findsOneWidget);
  });

  testWidgets('the gamepad close action closes the launcher', (tester) async {
    final h = await pumpLauncher(tester);

    await h.press(tester, GamepadAction.close);

    expect(h.closes, 1);
  });

  testWidgets('Ctrl+Q closes from the keyboard', (tester) async {
    final h = await pumpLauncher(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(h.closes, 1);
  });

  testWidgets('the first direction focuses the first navigation item', (
    tester,
  ) async {
    final h = await pumpLauncher(tester);

    await h.press(tester, GamepadAction.down);

    expect(hasFocus(tester, find.text('Início')), isTrue);
  });

  testWidgets('RB and LB change the section and bring the focus along', (
    tester,
  ) async {
    final h = await pumpLauncher(tester);

    await h.pressAndSettle(tester, GamepadAction.tabNext);
    expect(find.text('6 instalados'), findsOneWidget);
    expect(hasFocus(tester, find.text('Aplicativos').first), isTrue);

    await h.pressAndSettle(tester, GamepadAction.tabPrevious);
    await h.pressAndSettle(tester, GamepadAction.tabPrevious);
    expect(find.text('Painéis da tela inicial'), findsOneWidget);
    expect(hasFocus(tester, find.text('Configurações').first), isTrue);
  });

  testWidgets('Start opens the quick controls on top, B and Start close them', (
    tester,
  ) async {
    final h = await pumpLauncher(tester);
    await h.pressAndSettle(tester, GamepadAction.tabNext);

    await h.pressAndSettle(tester, GamepadAction.quickControls);
    expect(find.byType(QuickControlsPanel), findsOneWidget);
    expect(hasFocus(tester, find.text('Wi-Fi').last), isTrue);

    await h.pressAndSettle(tester, GamepadAction.back);
    expect(find.byType(QuickControlsPanel), findsNothing);

    await h.pressAndSettle(tester, GamepadAction.quickControls);
    await h.pressAndSettle(tester, GamepadAction.quickControls);
    expect(find.byType(QuickControlsPanel), findsNothing);
  });

  testWidgets('tabs are ignored while an overlay is open', (tester) async {
    final h = await pumpLauncher(tester);
    await h.pressAndSettle(tester, GamepadAction.tabNext);
    await h.pressAndSettle(tester, GamepadAction.quickControls);

    await h.pressAndSettle(tester, GamepadAction.tabNext);
    await h.pressAndSettle(tester, GamepadAction.search);

    expect(find.text('6 instalados'), findsOneWidget);
  });

  testWidgets('confirm in the quick controls toggles wifi', (tester) async {
    final h = await pumpLauncher(tester);
    await h.pressAndSettle(tester, GamepadAction.tabNext);
    await h.pressAndSettle(tester, GamepadAction.quickControls);

    await h.pressAndSettle(tester, GamepadAction.confirm);

    expect(h.backend.calls, contains('setWifiEnabled(false)'));
  });

  testWidgets('hidden panels disappear and Start/Y then do nothing', (
    tester,
  ) async {
    final backend = FakeBackend(
      settings: sampleSettings(panels: _onlyNavigation()),
    );
    final h = await pumpLauncher(tester, backend: backend);

    expect(find.text('Aplicativos favoritos'), findsNothing);
    expect(find.text('Sistema'), findsNothing);
    expect(find.text('Recentes'), findsNothing);
    expect(find.text(searchHint), findsNothing);
    expect(find.text('Continuar'), findsNothing);
    expect(find.text('Início'), findsOneWidget);

    await h.pressAndSettle(tester, GamepadAction.quickControls);
    await h.pressAndSettle(tester, GamepadAction.search);
    expect(find.byType(QuickControlsPanel), findsNothing);
  });

  testWidgets('Y opens the search on top of the current section', (
    tester,
  ) async {
    final h = await pumpLauncher(tester);
    await h.pressAndSettle(tester, GamepadAction.tabNext);

    await h.pressAndSettle(tester, GamepadAction.search);

    expect(find.byType(SearchOverlay), findsOneWidget);
    expect(find.text('6 instalados'), findsOneWidget);
  });

  testWidgets('a failed launch shows a message on screen', (tester) async {
    final h = await pumpLauncher(tester);
    h.backend.failures['launchApp'] =
        'apps de terminal ainda não são suportados';

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Não foi possível abrir VS Code: apps de terminal ainda não são '
        'suportados',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the theme follows the settings', (tester) async {
    final backend = FakeBackend(
      settings: sampleSettings(themeMode: LauncherThemeMode.light),
    );
    await pumpLauncher(tester, backend: backend);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(backend.calls, contains('resolveTheme(${19 * 60 + 42})'));
  });

  testWidgets('a theme the core cannot resolve falls back to dark', (
    tester,
  ) async {
    final backend = FakeBackend()..failures['resolveTheme'] = 'inválido';
    await pumpLauncher(tester, backend: backend);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('nothing is read from the system while the launcher is hidden', (
    tester,
  ) async {
    final h = await pumpLauncher(tester);
    int reads() =>
        h.backend.calls.where((call) => call == 'sampleStats').length;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    final before = reads();
    await tester.pump(const Duration(seconds: 5));
    expect(reads(), before);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(reads(), greaterThan(before));
    expect(
      h.backend.calls.where((c) => c.startsWith('listRecents')).length,
      2,
      reason: 'ao voltar, os recentes são relidos',
    );
  });

  testWidgets('the system panel reads once per second', (tester) async {
    final h = await pumpLauncher(tester);
    int reads() =>
        h.backend.calls.where((call) => call == 'sampleStats').length;
    final before = reads();

    await tester.pump(const Duration(seconds: 3));

    expect(reads() - before, 3);
    expect(find.text('4.2 / 16 GB'), findsOneWidget);
    expect(find.text('12%'), findsOneWidget);
  });

  testWidgets('favorites can be added from the picker and it closes with B', (
    tester,
  ) async {
    final h = await pumpLauncher(tester);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Escolha os favoritos'), findsOneWidget);

    await tester.tap(find.text('Steam'));
    await tester.pumpAndSettle();
    expect(h.backend.saved.last.favorites.last, 'steam.desktop');

    await h.pressAndSettle(tester, GamepadAction.back);
    expect(find.text('Escolha os favoritos'), findsNothing);
  });

  testWidgets('the gamepad icon hides when no controller is connected', (
    tester,
  ) async {
    final backend = FakeBackend(isGamepadConnected: false);
    await pumpLauncher(tester, backend: backend);

    expect(find.bySemanticsLabel('Controle conectado'), findsNothing);
  });

  testWidgets('unavailable controls show as such without breaking the panel', (
    tester,
  ) async {
    final backend = FakeBackend(quickControls: offlineQuickControls);
    await pumpLauncher(tester, backend: backend);

    expect(find.text(unavailableLabel), findsNWidgets(5));
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    expect(
      find.byIcon(Icons.signal_wifi_statusbar_null_rounded),
      findsOneWidget,
    );
  });
}
