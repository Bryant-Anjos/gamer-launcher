import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/state/settings_edit.dart';

import '../support/samples.dart';

void main() {
  final base = sampleSettings();

  test('copyWith changes only what is given', () {
    final next = base.copyWith(themeMode: LauncherThemeMode.light);

    expect(next.themeMode, LauncherThemeMode.light);
    expect(next.favorites, base.favorites);
    expect(next.panels, base.panels);
    expect(base.themeMode, LauncherThemeMode.dark, reason: 'original intacto');
  });

  test('the wallpaper can be set and cleared', () {
    final withWallpaper = base.withWallpaper('/walls/a.png');

    expect(withWallpaper.wallpaper, '/walls/a.png');
    expect(withWallpaper.withWallpaper(null).wallpaper, isNull);
  });

  test('toggling a favorite adds it at the end and removes it again', () {
    final added = base.toggleFavorite('new.desktop');

    expect(added.favorites.last, 'new.desktop');
    expect(added.toggleFavorite('new.desktop').favorites, base.favorites);
    expect(base.favorites, isNot(contains('new.desktop')));
  });

  test('every panel kind reads and writes its own flag', () {
    for (final kind in PanelKind.values) {
      final hidden = base.withPanel(kind, false);

      expect(kind.isVisibleIn(hidden), isFalse, reason: kind.name);
      for (final other in PanelKind.values.where((k) => k != kind)) {
        expect(
          other.isVisibleIn(hidden),
          isTrue,
          reason:
              '${other.name} '
              'não pode mudar ao esconder ${kind.name}',
        );
      }
    }
  });

  test('every panel kind has a label', () {
    for (final kind in PanelKind.values) {
      expect(kind.label, isNotEmpty);
    }
  });

  test('the auto schedule changes both times', () {
    final next = base.withSchedule(
      darkStartsMinute: 1200,
      lightStartsMinute: 420,
    );

    expect(next.darkStartsMinute, 1200);
    expect(next.lightStartsMinute, 420);
  });

  test('layout, sounds and animations change one at a time and survive other edits', () {
    final edited = base
        .copyWith(buttonLayout: LauncherButtonLayout.nintendo)
        .copyWith(sounds: true)
        .copyWith(reduceAnimations: true);

    expect(edited.buttonLayout, LauncherButtonLayout.nintendo);
    expect(edited.sounds, isTrue);
    expect(edited.reduceAnimations, isTrue);
    expect(edited.withWallpaper('/a.png').sounds, isTrue);
    expect(base.sounds, isFalse, reason: 'original intacto');
  });
}
