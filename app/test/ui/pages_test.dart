import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/state/settings_edit.dart';
import 'package:gamer_launcher/ui/home/recents_panel.dart';
import 'package:gamer_launcher/ui/pages/apps_page.dart';
import 'package:gamer_launcher/ui/pages/games_page.dart' show noLaunchersText;
import 'package:gamer_launcher/ui/settings/wallpaper_picker.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';
import '../support/samples.dart';

Future<LauncherHarness> _openSection(
  WidgetTester tester,
  int tabs, {
  FakeBackend? backend,
}) async {
  final h = await pumpLauncher(tester, backend: backend);
  for (var i = 0; i < tabs; i++) {
    await h.pressAndSettle(tester, GamepadAction.tabNext);
  }
  return h;
}

void main() {
  group('Aplicativos', () {
    testWidgets('lists every app and opens one with confirm', (tester) async {
      final h = await _openSection(tester, 1);

      for (final app in sampleApps) {
        expect(find.text(app.name), findsWidgets, reason: app.name);
      }
      await h.press(tester, GamepadAction.right);
      expect(hasFocus(tester, find.text('Chrome')), isTrue);
      await h.press(tester, GamepadAction.confirm);

      expect(h.backend.calls, contains('launchApp(chrome.desktop)'));
    });

    testWidgets('says so when there are no apps', (tester) async {
      final backend = FakeBackend(catalog: sampleCatalog(apps: const []));
      await _openSection(tester, 1, backend: backend);

      expect(find.text(noAppsText), findsOneWidget);
    });
  });

  group('Jogos', () {
    testWidgets('shows the installed launchers', (tester) async {
      final h = await _openSection(tester, 2);

      await tester.tap(find.text('Steam'));
      await tester.pump();

      expect(h.backend.calls, contains('launchApp(steam.desktop)'));
    });

    testWidgets('explains what to install when there is none', (tester) async {
      final backend = FakeBackend(
        catalog: sampleCatalog(gameLauncherIds: const []),
      );
      await _openSection(tester, 2, backend: backend);

      expect(find.text(noLaunchersText), findsOneWidget);
    });
  });

  group('Arquivos', () {
    testWidgets('lists the recents and opens one', (tester) async {
      final h = await _openSection(tester, 3);

      expect(find.text('Documentação.docx'), findsOneWidget);
      await tester.tap(find.text('eisaqui'));
      await tester.pump();

      expect(h.backend.calls, contains('openPath(/home/b/Projetos/eisaqui)'));
    });

    testWidgets('says when nothing was opened recently', (tester) async {
      final backend = FakeBackend(recents: const []);
      await _openSection(tester, 3, backend: backend);

      expect(find.text(noRecentsText), findsOneWidget);
    });
  });

  group('Configurações', () {
    testWidgets('choosing a theme saves it', (tester) async {
      final h = await _openSection(tester, 4);

      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();

      expect(h.backend.saved.last.themeMode, LauncherThemeMode.light);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
    });

    testWidgets('the automatic schedule is adjusted with left and right', (
      tester,
    ) async {
      final backend = FakeBackend(
        settings: sampleSettings(themeMode: LauncherThemeMode.auto),
      );
      final h = await _openSection(tester, 4, backend: backend);
      expect(find.text('19:00'), findsOneWidget);

      Focus.of(tester.element(find.text('Escuro a partir de'))).requestFocus();
      await tester.pump();
      await h.pressAndSettle(tester, GamepadAction.right);

      expect(h.backend.saved.last.darkStartsMinute, 19 * 60 + 30);
      expect(find.text('19:30'), findsOneWidget);

      await tester.tap(find.byTooltip('Mais cedo').last);
      await tester.pumpAndSettle();
      expect(h.backend.saved.last.lightStartsMinute, 5 * 60 + 30);
    });

    testWidgets('the schedule only shows in automatic mode', (tester) async {
      await _openSection(tester, 4);

      expect(find.text('Escuro a partir de'), findsNothing);
    });

    testWidgets('hiding a panel saves it and the home loses it', (
      tester,
    ) async {
      final h = await _openSection(tester, 4);

      await tester.tap(find.text(PanelKind.system.label));
      await tester.pumpAndSettle();
      expect(h.backend.saved.last.panels.system, isFalse);

      await h.pressAndSettle(tester, GamepadAction.tabNext);
      expect(find.text('Sistema'), findsNothing);
      expect(find.text('Recentes'), findsOneWidget);
    });

    testWidgets('a wallpaper can be chosen and removed', (tester) async {
      final backend = FakeBackend(
        wallpapers: ['/walls/montanha.png', '/walls/praia.jpg'],
      );
      final h = await _openSection(tester, 4, backend: backend);

      await tester.tap(find.bySemanticsLabel(RegExp('^praia.jpg')));
      await tester.pumpAndSettle();
      expect(h.backend.saved.last.wallpaper, '/walls/praia.jpg');

      await tester.tap(find.text(noWallpaperLabel));
      await tester.pumpAndSettle();
      expect(h.backend.saved.last.wallpaper, isNull);
    });

    testWidgets('a broken wallpaper file falls back to the plain color', (
      tester,
    ) async {
      final backend = FakeBackend(
        settings: sampleSettings(wallpaper: '/no/such/wall.png'),
      );
      await pumpLauncher(tester, backend: backend);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('Boa noite, Bryant'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failure to list images is shown', (tester) async {
      final backend = FakeBackend()..failures['listWallpapers'] = 'sem acesso';
      await _openSection(tester, 4, backend: backend);

      expect(
        find.text('Não foi possível listar as imagens: sem acesso'),
        findsOneWidget,
      );
    });

    testWidgets('shows the core version', (tester) async {
      await _openSection(tester, 4);
      await tester.scrollUntilVisible(find.text('Núcleo 0.1.0'), 200);

      expect(find.text('Núcleo 0.1.0'), findsOneWidget);
    });
  });

  group('Cartões de destaque', () {
    testWidgets('Projetos goes to the files section', (tester) async {
      await pumpLauncher(tester);

      await tester.tap(find.text('Projetos'));
      await tester.pumpAndSettle();

      expect(
        find.text('Arquivos e pastas abertos recentemente'),
        findsOneWidget,
      );
    });

    testWidgets('Músicas opens the player and Jogos the only launcher', (
      tester,
    ) async {
      final h = await pumpLauncher(tester);

      await tester.tap(find.text('Músicas'));
      await tester.tap(find.text('Iniciar biblioteca'));
      await tester.pump();

      expect(h.backend.calls, contains('launchApp(spotify.desktop)'));
      expect(h.backend.calls, contains('launchApp(steam.desktop)'));
    });

    testWidgets('Jogos with several launchers opens the games section', (
      tester,
    ) async {
      final backend = FakeBackend(
        catalog: sampleCatalog(
          apps: [...sampleApps, sampleApp('lutris.desktop', 'Lutris')],
          gameLauncherIds: const ['steam.desktop', 'lutris.desktop'],
        ),
      );
      await pumpLauncher(tester, backend: backend);

      await tester.tap(find.text('Iniciar biblioteca'));
      await tester.pumpAndSettle();

      expect(find.text('Abra a biblioteca no seu lançador'), findsOneWidget);
      expect(find.byType(AppTile), findsNWidgets(2));
    });

    testWidgets('cards without an app are disabled with a reason', (
      tester,
    ) async {
      final backend = FakeBackend(
        catalog: sampleCatalog(
          gameLauncherIds: const [],
          musicPlayerId: null,
          lastAppId: null,
        ),
      );
      final h = await pumpLauncher(tester, backend: backend);

      expect(find.text('Nenhum app aberto ainda'), findsOneWidget);
      expect(
        find.text('Steam, Heroic ou Lutris não encontrados'),
        findsOneWidget,
      );
      expect(find.text('Nenhum player encontrado'), findsOneWidget);
      await tester.tap(find.text('Músicas'));
      await tester.pump();
      expect(h.backend.calls.where((c) => c.startsWith('launchApp')), isEmpty);
    });

    testWidgets('favorites open their app', (tester) async {
      final h = await pumpLauncher(tester);

      await tester.tap(find.bySemanticsLabel(RegExp('^Discord')));
      await tester.pump();

      expect(h.backend.calls, contains('launchApp(discord.desktop)'));
    });

    testWidgets('a recent on the home opens', (tester) async {
      final h = await pumpLauncher(tester);

      await tester.tap(find.text('granspace'));
      await tester.pump();

      expect(h.backend.calls, contains('openPath(/home/b/Projetos/granspace)'));
    });
  });
}
