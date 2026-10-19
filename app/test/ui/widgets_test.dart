import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/input/adjust_intent.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/quick/quick_controls_panel.dart';
import 'package:gamer_launcher/ui/shell/top_bar.dart';
import 'package:gamer_launcher/ui/widgets/app_icon.dart';
import 'package:gamer_launcher/ui/widgets/charts.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';
import 'package:gamer_launcher/ui/widgets/level_slider.dart';

Widget _themed(Widget child, {Brightness brightness = Brightness.dark}) =>
    MaterialApp(
      theme: buildLauncherTheme(brightness),
      home: Scaffold(body: Center(child: child)),
    );

BoxDecoration _decorationAround(WidgetTester tester, Finder finder) {
  final container = tester.widget<AnimatedContainer>(
    find.ancestor(of: finder, matching: find.byType(AnimatedContainer)).first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  group('FocusTile', () {
    testWidgets('draws the focus ring only while focused', (tester) async {
      await tester.pumpWidget(
        _themed(FocusTile(onActivate: () {}, child: const Text('item'))),
      );
      Color ring() =>
          (_decorationAround(tester, find.text('item')).border! as Border)
              .top
              .color;
      expect(ring(), Colors.transparent);

      Focus.of(tester.element(find.text('item'))).requestFocus();
      await tester.pumpAndSettle();

      expect(ring(), LauncherPalette.dark.focusRing);
      expect(
        _decorationAround(tester, find.text('item')).boxShadow,
        isNotEmpty,
      );
    });

    testWidgets('activates with Enter and with a click', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _themed(FocusTile(onActivate: () => taps++, child: const Text('ok'))),
      );

      await tester.tap(find.text('ok'));
      Focus.of(tester.element(find.text('ok'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(taps, 2);
    });

    testWidgets('without an action it cannot take the focus', (tester) async {
      await tester.pumpWidget(_themed(const FocusTile(child: Text('mudo'))));

      final node = Focus.of(tester.element(find.text('mudo')));

      expect(node.canRequestFocus, isFalse);
    });

    testWidgets('a hover shows a light highlight', (tester) async {
      // no desktop o modo de destaque é o tradicional; no teste é o de toque
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await tester.pumpWidget(
        _themed(FocusTile(onActivate: () {}, child: const Text('mouse'))),
      );
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(find.text('mouse')));
      await tester.pumpAndSettle();

      final container = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text('mouse'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(container.foregroundDecoration, isNotNull);
    });
  });

  group('LevelSlider', () {
    Future<List<int>> pumpSlider(WidgetTester tester, int? value) async {
      final changes = <int>[];
      await tester.pumpWidget(
        _themed(
          SizedBox(
            width: 400,
            child: LevelSlider(
              icon: Icons.volume_up_rounded,
              label: 'Volume',
              value: value,
              onChanged: changes.add,
            ),
          ),
        ),
      );
      return changes;
    }

    testWidgets('steps with AdjustIntent and with the arrow keys', (
      tester,
    ) async {
      final changes = await pumpSlider(tester, 50);
      final focus = Focus.of(tester.element(find.text('50%')));
      focus.requestFocus();
      await tester.pump();

      Actions.invoke(focus.context!, const AdjustIntent(1));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);

      expect(changes, [55, 45]);
    });

    testWidgets('does not go past the ends', (tester) async {
      final changes = await pumpSlider(tester, 100);
      final focus = Focus.of(tester.element(find.text('100%')));

      Actions.invoke(focus.context!, const AdjustIntent(1));

      expect(changes, isEmpty);
    });

    testWidgets('a click on the track sets the value', (tester) async {
      final changes = await pumpSlider(tester, 10);
      final track = find.byType(GestureDetector).last;

      await tester.tapAt(tester.getBottomRight(track) - const Offset(1, 9));

      expect(changes.single, 100);
    });

    testWidgets('without a reading it shows as unavailable', (tester) async {
      await pumpSlider(tester, null);

      expect(find.text('Indisponível'), findsOneWidget);
      expect(find.byType(FocusTile), findsNothing);
    });
  });

  group('AppIcon', () {
    testWidgets('without a file shows the initial', (tester) async {
      await tester.pumpWidget(
        _themed(const AppIcon(name: 'firefox', iconPath: null, size: 48)),
      );

      expect(find.text('F'), findsOneWidget);
    });

    testWidgets('an empty name still draws something', (tester) async {
      await tester.pumpWidget(_themed(const LetterIcon(name: '  ', size: 48)));

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('svg files use the svg renderer', (tester) async {
      await tester.pumpWidget(
        _themed(
          const AppIcon(name: 'Files', iconPath: '/icons/files.svg', size: 48),
        ),
      );

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('a bitmap that cannot be read falls back to the initial', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('icon');
      addTearDown(() => dir.deleteSync(recursive: true));
      final broken = File('${dir.path}/broken.png')..writeAsStringSync('x');

      await tester.runAsync(() async {
        await tester.pumpWidget(
          _themed(AppIcon(name: 'Brave', iconPath: broken.path, size: 48)),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(find.text('B'), findsOneWidget);
    });
  });

  group('QuickToggle', () {
    testWidgets('a failed reading is shown as unavailable with the reason', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          QuickToggle(
            icon: Icons.bluetooth_rounded,
            label: 'Bluetooth',
            reading: const ToggleReading(error: 'sem adaptador'),
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text(unavailableLabel), findsOneWidget);
      expect(find.byTooltip('sem adaptador'), findsOneWidget);
    });

    testWidgets('before the first reading it says it is reading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          QuickToggle(
            icon: Icons.wifi_rounded,
            label: 'Wi-Fi',
            reading: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Lendo...'), findsOneWidget);
    });

    testWidgets('confirm flips the value', (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _themed(
          QuickToggle(
            icon: Icons.dark_mode_rounded,
            label: 'Modo escuro',
            reading: const ToggleReading(enabled: false),
            onChanged: changes.add,
          ),
          brightness: Brightness.light,
        ),
      );

      await tester.tap(find.text('Modo escuro'));

      expect(find.text('Desativado'), findsOneWidget);
      expect(changes, [true]);
    });
  });

  group('status icons', () {
    test('wifi follows the reading', () {
      const on = QuickControls(
        wifi: ToggleReading(enabled: true),
        bluetooth: ToggleReading(),
        darkMode: ToggleReading(),
        volume: LevelReading(muted: false),
        brightness: LevelReading(muted: false),
      );

      expect(wifiIcon(on), Icons.wifi_rounded);
      expect(wifiIcon(null), Icons.signal_wifi_statusbar_null_rounded);
    });

    test('volume shows muted and zero as off', () {
      expect(
        volumeIcon(const LevelReading(percent: 40, muted: true)),
        Icons.volume_off_rounded,
      );
      expect(
        volumeIcon(const LevelReading(percent: 0, muted: false)),
        Icons.volume_off_rounded,
      );
      expect(
        volumeIcon(const LevelReading(percent: 40, muted: false)),
        Icons.volume_up_rounded,
      );
      expect(volumeIcon(null), Icons.volume_off_outlined);
    });
  });

  group('charts', () {
    testWidgets('ring and sparkline paint without errors', (tester) async {
      await tester.pumpWidget(
        _themed(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RingGauge(percent: 140, color: Colors.blue, size: 30),
              SizedBox(
                width: 100,
                height: 30,
                child: Sparkline(
                  values: [10, 50, 30, 90],
                  color: Colors.green,
                  capacity: 30,
                ),
              ),
              SizedBox(
                width: 100,
                height: 30,
                child: Sparkline(values: [5], color: Colors.red, capacity: 30),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  test('palettes interpolate and copy', () {
    final halfway = LauncherPalette.dark.lerp(LauncherPalette.light, 0.5);

    expect(halfway.background, isNot(LauncherPalette.dark.background));
    expect(LauncherPalette.dark.lerp(null, 0.5), LauncherPalette.dark);
    expect(
      LauncherPalette.dark.copyWith(accent: Colors.red).accent,
      Colors.red,
    );
    expect(LauncherPalette.dark.copyWith().accent, LauncherPalette.dark.accent);
  });
}
