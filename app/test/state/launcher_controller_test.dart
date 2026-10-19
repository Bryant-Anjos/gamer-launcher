import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/state/launcher_controller.dart';
import 'package:gamer_launcher/state/messages.dart';
import 'package:gamer_launcher/state/settings_edit.dart';

import '../support/fake_backend.dart';
import '../support/samples.dart';

class _Setup {
  _Setup([FakeBackend? backend]) : backend = backend ?? FakeBackend() {
    messages.stream.listen(shown.add);
    controller = LauncherController(this.backend, messages);
  }

  final FakeBackend backend;
  final messages = LauncherMessages();
  final shown = <String>[];
  late final LauncherController controller;

  LauncherState get state => controller.value;

  Future<void> settle() => Future<void>.delayed(Duration.zero);
}

void main() {
  test('starts with the default settings and nothing loaded', () {
    final s = _Setup();

    expect(s.state.isReady, isFalse);
    expect(s.state.settings.themeMode, LauncherThemeMode.auto);
    expect(s.state.section, Section.home);
    expect(s.state.catalog.apps, isEmpty);
  });

  test('load brings settings, apps, recents and the user name', () async {
    final s = _Setup();

    await s.controller.load();

    expect(s.state.isReady, isTrue);
    expect(s.state.settings, s.backend.settings);
    expect(s.state.catalog.apps, hasLength(sampleApps.length));
    expect(s.state.recents, hasLength(3));
    expect(s.state.userName, 'Bryant');
    expect(s.state.lastApp?.name, 'VS Code');
    await s.settle();
    expect(s.shown, isEmpty);
  });

  test('broken settings fall back to defaults with a warning and are not '
      'overwritten', () async {
    final s = _Setup()..backend.failures['loadSettings'] = 'arquivo inválido';

    await s.controller.load();
    await s.settle();

    expect(s.state.settings.themeMode, LauncherThemeMode.auto);
    expect(s.backend.saved, isEmpty);
    expect(s.shown.single, contains('arquivo inválido'));
  });

  test('catalog warnings and failures become messages', () async {
    final warned = _Setup(
      FakeBackend(catalog: sampleCatalog(warnings: ['histórico inválido'])),
    );
    await warned.controller.load();
    await warned.settle();
    expect(warned.shown, ['histórico inválido']);

    final failed = _Setup()..backend.failures['loadCatalog'] = 'sem apps';
    await failed.controller.load();
    await failed.settle();
    expect(failed.state.catalog.apps, isEmpty);
    expect(failed.shown.single, contains('sem apps'));
    expect(failed.state.isReady, isTrue);
  });

  test('unreadable recents leave the list empty with a message', () async {
    final s = _Setup()..backend.failures['listRecents'] = 'xbel quebrado';

    await s.controller.load();
    await s.settle();

    expect(s.state.recents, isEmpty);
    expect(s.shown.single, contains('xbel quebrado'));
  });

  test('sections cycle in both directions and wrap around', () {
    final s = _Setup();

    s.controller.cycleSection(-1);
    expect(s.state.section, Section.settings);
    s.controller.cycleSection(1);
    expect(s.state.section, Section.home);
    s.controller.cycleSection(1);
    expect(s.state.section, Section.apps);

    s.controller.selectSection(Section.files);
    expect(s.state.section, Section.files);
  });

  test('updating settings saves them and applies them', () async {
    final s = _Setup();
    await s.controller.load();
    final next = s.state.settings.copyWith(themeMode: LauncherThemeMode.light);

    await s.controller.updateSettings(next);

    expect(s.backend.saved.single, next);
    expect(s.state.settings, next);
  });

  test('settings the core refuses are not applied', () async {
    final s = _Setup();
    await s.controller.load();
    final before = s.state.settings;
    s.backend.failures['saveSettings'] = 'horários iguais';

    await s.controller.updateSettings(
      before.withSchedule(darkStartsMinute: 60, lightStartsMinute: 60),
    );
    await s.settle();

    expect(s.state.settings, before);
    expect(s.shown.single, contains('horários iguais'));
  });

  test('toggling a favorite saves the new list', () async {
    final s = _Setup();
    await s.controller.load();

    await s.controller.toggleFavorite('steam.desktop');

    expect(s.state.settings.favorites.last, 'steam.desktop');
    expect(s.state.favoriteApps.last.name, 'Steam');
  });

  test('favorites keep their order and skip apps that are gone', () async {
    final s = _Setup(
      FakeBackend(
        settings: sampleSettings(
          favorites: ['spotify.desktop', 'gone.desktop', 'chrome.desktop'],
        ),
      ),
    );

    await s.controller.load();

    expect(s.state.favoriteApps.map((app) => app.name), ['Spotify', 'Chrome']);
  });

  test('launching an app makes it the one to continue', () async {
    final s = _Setup();
    await s.controller.load();

    await s.controller.launchApp('spotify.desktop');
    await s.settle();

    expect(s.backend.calls, contains('launchApp(spotify.desktop)'));
    expect(s.state.lastApp?.name, 'Spotify');
    expect(s.shown, isEmpty);
  });

  test('a failed launch shows a friendly message with the app name', () async {
    final s = _Setup();
    await s.controller.load();
    s.backend.failures['launchApp'] = 'programa ou arquivo não encontrado';

    await s.controller.launchApp('code.desktop');
    await s.settle();

    expect(
      s.shown.single,
      'Não foi possível abrir VS Code: programa ou arquivo não encontrado',
    );
    expect(s.state.lastApp?.name, 'VS Code');
  });

  test('a launch warning is shown but the app counts as opened', () async {
    final s = _Setup();
    await s.controller.load();
    s.backend.launchWarning = 'histórico não gravado';

    await s.controller.launchApp('chrome.desktop');
    await s.settle();

    expect(s.shown.single, 'histórico não gravado');
    expect(s.state.lastApp?.name, 'Chrome');
  });

  test('opening a recent file reports failures', () async {
    final s = _Setup();
    await s.controller.load();
    s.backend.failures['openPath'] = 'não existe mais';

    await s.controller.openRecent(sampleRecents.first);
    await s.settle();

    expect(s.backend.calls, contains('openPath(${sampleRecents.first.path})'));
    expect(s.shown.single, 'Não foi possível abrir granspace: não existe mais');
  });

  test('featured apps come from the catalog', () async {
    final s = _Setup();
    await s.controller.load();

    expect(s.state.gameLaunchers.map((app) => app.name), ['Steam']);
    expect(s.state.musicPlayer?.name, 'Spotify');
  });

  test('a missing name does not break the greeting data', () async {
    final s = _Setup()..backend.failures['userFirstName'] = 'sem passwd';

    await s.controller.load();

    expect(s.state.userName, isNull);
  });

  test('quick edits in a row are all kept, in order', () async {
    final s = _Setup();
    await s.controller.load();
    final gate = Completer<void>();
    s.backend.gates['saveSettings'] = gate;

    final first = s.controller.toggleFavorite('steam.desktop');
    final second = s.controller.toggleFavorite('code.desktop');
    await s.settle();
    gate.complete();
    await Future.wait([first, second]);

    expect(s.state.settings.favorites, contains('steam.desktop'));
    expect(s.state.settings.favorites, isNot(contains('code.desktop')));
    expect(s.backend.saved.last.favorites, s.state.settings.favorites);
  });

  test('an edit refused by the core does not block the next one', () async {
    final s = _Setup();
    await s.controller.load();
    s.backend.failures['saveSettings'] = 'disco cheio';

    await s.controller.editSettings(
      (settings) => settings.copyWith(themeMode: LauncherThemeMode.light),
    );
    s.backend.failures.clear();
    await s.controller.editSettings(
      (settings) => settings.copyWith(themeMode: LauncherThemeMode.auto),
    );

    expect(s.state.settings.themeMode, LauncherThemeMode.auto);
  });
}
