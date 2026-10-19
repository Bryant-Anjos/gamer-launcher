import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/input/adjust_intent.dart';
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
    // como no app: o roteador fica acima do Navigator (MaterialApp.builder)
    return MaterialApp(
      builder: (context, child) => InputRouter(
        actions: controller.stream,
        onClose: () => closes++,
        onSearch: onSearch,
        onQuickControls: onQuickControls,
        onTabChange: onTabChange,
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: layout == Axis.vertical
              ? Column(mainAxisSize: MainAxisSize.min, children: buttons)
              : Row(mainAxisSize: MainAxisSize.min, children: buttons),
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
  _registerOverlayTests();

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
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Segunda tela')),
        ),
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

Future<void> _openDialog(WidgetTester tester, _Taps taps) async {
  final context = tester.element(find.text('A'));
  unawaited(
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_button('D', taps), _button('E', taps)],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Stepper extends StatefulWidget {
  const _Stepper();

  @override
  State<_Stepper> createState() => _StepperState();
}

class _StepperState extends State<_Stepper> {
  int value = 0;

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      AdjustIntent: CallbackAction<AdjustIntent>(
        onInvoke: (intent) => setState(() => value += intent.step),
      ),
    },
    child: Focus(child: Text('valor $value')),
  );
}

void _registerOverlayTests() {
  testWidgets('with a dialog open, a direction focuses the dialog, not the '
      'screen behind it', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await _openDialog(tester, h.taps);

    await h.send(tester, GamepadAction.down);

    expect(_hasFocus(tester, 'D'), isTrue);
  });

  testWidgets('focus moves inside the dialog and confirm activates there', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await _openDialog(tester, h.taps);
    await h.send(tester, GamepadAction.down);

    await h.send(tester, GamepadAction.down);
    await h.send(tester, GamepadAction.confirm);

    expect(_hasFocus(tester, 'E'), isTrue);
    expect(h.taps, ['E']);
  });

  testWidgets('Ctrl+Q closes even with a dialog open', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await _openDialog(tester, h.taps);
    await h.send(tester, GamepadAction.down);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(h.closes, 1);
  });

  testWidgets('back closes the dialog and keeps the screen behind', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await _openDialog(tester, h.taps);

    await h.send(tester, GamepadAction.back);
    await tester.pumpAndSettle();

    expect(find.text('D'), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('left and right adjust a focused control instead of moving', (
    tester,
  ) async {
    final controller = StreamController<GamepadAction>.broadcast();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => InputRouter(
          actions: controller.stream,
          onClose: () {},
          child: child!,
        ),
        home: const Scaffold(
          body: Column(
            children: [
              _Stepper(),
              Focus(child: Text('abaixo')),
            ],
          ),
        ),
      ),
    );
    Future<void> send(GamepadAction action) async {
      controller.add(action);
      // o evento chega depois do primeiro frame; o segundo mostra o valor
      await tester.pump();
      await tester.pump();
    }

    await send(GamepadAction.down);
    await send(GamepadAction.right);
    await send(GamepadAction.right);
    await send(GamepadAction.left);

    expect(find.text('valor 1'), findsOneWidget);
    expect(
      Focus.of(tester.element(find.text('valor 1'))).hasPrimaryFocus,
      isTrue,
    );

    await send(GamepadAction.down);
    expect(
      Focus.of(tester.element(find.text('abaixo'))).hasPrimaryFocus,
      isTrue,
      reason: 'cima e baixo continuam movendo o foco',
    );
  });

  testWidgets('stream errors reach the error callback', (tester) async {
    final controller = StreamController<GamepadAction>.broadcast();
    final errors = <Object>[];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => InputRouter(
          actions: controller.stream,
          onClose: () {},
          onError: errors.add,
          child: child!,
        ),
        home: const Scaffold(),
      ),
    );

    controller.addError(StateError('sem controle'));
    await tester.pump();

    expect(errors, hasLength(1));
  });
}
