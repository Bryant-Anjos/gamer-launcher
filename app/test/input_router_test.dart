import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/input/input_router.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';

typedef _Taps = List<String>;

Widget _button(String label, _Taps taps) =>
    ElevatedButton(onPressed: () => taps.add(label), child: Text(label));

class _Harness {
  _Harness({
    this.layout = Axis.vertical,
    this.onSearch,
    this.onQuickControls,
    this.onTabChange,
  }) : controller = StreamController<GamepadAction>.broadcast();

  final Axis layout;
  final VoidCallback? onSearch;
  final VoidCallback? onQuickControls;
  final ValueChanged<int>? onTabChange;
  final StreamController<GamepadAction> controller;
  final taps = <String>[];
  int closes = 0;

  Widget build() {
    final buttons = [
      for (final label in ['A', 'B', 'C']) _button(label, taps),
    ];
    return MaterialApp(
      home: InputRouter(
        actions: controller.stream,
        onClose: () => closes++,
        onSearch: onSearch,
        onQuickControls: onQuickControls,
        onTabChange: onTabChange,
        child: Scaffold(
          body: Center(
            child: layout == Axis.vertical
                ? Column(mainAxisSize: MainAxisSize.min, children: buttons)
                : Row(mainAxisSize: MainAxisSize.min, children: buttons),
          ),
        ),
      ),
    );
  }

  Future<void> send(WidgetTester tester, GamepadAction action) async {
    controller.add(action);
    await tester.pump();
  }
}

bool _hasFocus(WidgetTester tester, String label) =>
    Focus.of(tester.element(find.text(label))).hasPrimaryFocus;

void main() {
  testWidgets('first direction press focuses the first item', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());

    await h.send(tester, GamepadAction.down);

    expect(_hasFocus(tester, 'A'), isTrue);
  });

  testWidgets('down and up move the focus through a column', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await h.send(tester, GamepadAction.down);

    await h.send(tester, GamepadAction.down);
    expect(_hasFocus(tester, 'B'), isTrue);

    await h.send(tester, GamepadAction.down);
    expect(_hasFocus(tester, 'C'), isTrue);

    await h.send(tester, GamepadAction.up);
    expect(_hasFocus(tester, 'B'), isTrue);
  });

  testWidgets('right and left move the focus through a row', (tester) async {
    final h = _Harness(layout: Axis.horizontal);
    await tester.pumpWidget(h.build());
    await h.send(tester, GamepadAction.right);

    await h.send(tester, GamepadAction.right);
    expect(_hasFocus(tester, 'B'), isTrue);

    await h.send(tester, GamepadAction.left);
    expect(_hasFocus(tester, 'A'), isTrue);
  });

  testWidgets('confirm activates the focused item', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await h.send(tester, GamepadAction.down);
    await h.send(tester, GamepadAction.down);

    await h.send(tester, GamepadAction.confirm);

    expect(h.taps, ['B']);
  });

  testWidgets('confirm with nothing focused does nothing', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());

    await h.send(tester, GamepadAction.confirm);

    expect(h.taps, isEmpty);
  });

  testWidgets('back pops a pushed route', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Segunda tela')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Segunda tela'), findsOneWidget);

    await h.send(tester, GamepadAction.back);
    await tester.pumpAndSettle();

    expect(find.text('Segunda tela'), findsNothing);
  });

  testWidgets('back on the home screen does not close the launcher', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());

    await h.send(tester, GamepadAction.back);
    await tester.pumpAndSettle();

    expect(h.closes, 0);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('close action asks the app to close', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());

    await h.send(tester, GamepadAction.close);

    expect(h.closes, 1);
  });

  testWidgets('Ctrl+Q closes from the keyboard', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(h.closes, 1);
  });

  testWidgets('plain Q does not close', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());

    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.pump();

    expect(h.closes, 0);
  });

  testWidgets('search, quick controls and tabs reach their callbacks', (
    tester,
  ) async {
    var searches = 0;
    var panels = 0;
    final tabs = <int>[];
    final h = _Harness(
      onSearch: () => searches++,
      onQuickControls: () => panels++,
      onTabChange: tabs.add,
    );
    await tester.pumpWidget(h.build());

    await h.send(tester, GamepadAction.search);
    await h.send(tester, GamepadAction.quickControls);
    await h.send(tester, GamepadAction.tabNext);
    await h.send(tester, GamepadAction.tabPrevious);

    expect(
      [searches, panels, tabs],
      [
        1,
        1,
        [1, -1],
      ],
    );
  });

  testWidgets('missing optional callbacks are simply ignored', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());

    await h.send(tester, GamepadAction.search);
    await h.send(tester, GamepadAction.quickControls);
    await h.send(tester, GamepadAction.tabNext);

    expect(tester.takeException(), isNull);
  });

  testWidgets('stops listening when removed from the tree', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    expect(h.controller.hasListener, isTrue);

    await tester.pumpWidget(const SizedBox());

    expect(h.controller.hasListener, isFalse);
    h.controller.add(GamepadAction.close);
    await tester.pump();
    expect(h.closes, 0);
  });

  testWidgets('switches to a new stream when the widget is rebuilt', (
    tester,
  ) async {
    final first = StreamController<GamepadAction>.broadcast();
    final second = StreamController<GamepadAction>.broadcast();
    var closes = 0;
    Widget build(Stream<GamepadAction> stream) => MaterialApp(
      home: InputRouter(
        actions: stream,
        onClose: () => closes++,
        child: const Scaffold(),
      ),
    );

    await tester.pumpWidget(build(first.stream));
    await tester.pumpWidget(build(second.stream));
    first.add(GamepadAction.close);
    await tester.pump();
    expect(closes, 0);
    second.add(GamepadAction.close);
    await tester.pump();

    expect(closes, 1);
    expect(first.hasListener, isFalse);
  });
}
