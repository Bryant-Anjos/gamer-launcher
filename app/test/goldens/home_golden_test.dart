import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/ui/home/favorites_panel.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';
import '../support/samples.dart';

const _cpuHistory = [8.0, 15.0, 11.0, 22.0, 14.0, 12.0];

/// Alimenta alguns segundos de leituras para os gráficos terem forma.
Future<void> _feedStats(WidgetTester tester, FakeBackend backend) async {
  for (final cpu in _cpuHistory) {
    backend.stats = StatsSample(
      cpuPercent: cpu,
      ramUsedBytes: 4.2e9 + cpu * 1e7,
      ramTotalBytes: 16e9,
      diskUsedBytes: 120e9,
      diskTotalBytes: 500e9,
    );
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  setUpAll(loadLauncherFonts);

  testWidgets('home in the dark theme, with a focused card', (tester) async {
    final backend = FakeBackend(
      settings: sampleSettings(themeMode: LauncherThemeMode.dark),
    );
    await pumpLauncher(tester, backend: backend);
    await _feedStats(tester, backend);
    Focus.of(tester.element(find.text('Continuar'))).requestFocus();
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('home_dark.png'),
    );
  });

  testWidgets('home in the light theme', (tester) async {
    final backend = FakeBackend(
      settings: sampleSettings(themeMode: LauncherThemeMode.light),
    );
    await pumpLauncher(
      tester,
      backend: backend,
      now: DateTime(2026, 10, 17, 9, 5),
    );
    await _feedStats(tester, backend);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('home_light.png'),
    );
  });

  testWidgets('home on an ultrawide screen (2560x1080)', (tester) async {
    final backend = FakeBackend(
      settings: sampleSettings(themeMode: LauncherThemeMode.dark),
    );
    await pumpLauncher(tester, backend: backend, size: const Size(2560, 1080));
    await _feedStats(tester, backend);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('home_ultrawide.png'),
    );
  });

  testWidgets('home while moving a favorite', (tester) async {
    final h = await pumpLauncher(tester);
    Focus.of(
      tester.element(
        find
            .descendant(
              of: find.byWidgetPredicate(
                (w) => w is FavoriteTile && w.label == 'VS Code',
              ),
              matching: find.byType(AnimatedScale),
            )
            .first,
      ),
    ).requestFocus();
    await tester.pumpAndSettle();
    await h.pressAndSettle(tester, GamepadAction.secondary);
    await h.pressAndSettle(tester, GamepadAction.right);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('home_moving.png'),
    );
  });
}
