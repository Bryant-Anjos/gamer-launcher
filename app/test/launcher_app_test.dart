import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/launcher_app.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';

void main() {
  testWidgets('shows the core version it receives', (tester) async {
    await tester.pumpWidget(
      LauncherApp(
        coreVersion: '9.9.9',
        actions: const Stream.empty(),
        onClose: () {},
      ),
    );

    expect(find.text('Núcleo 9.9.9'), findsOneWidget);
  });

  testWidgets('does not show a debug banner', (tester) async {
    await tester.pumpWidget(
      LauncherApp(
        coreVersion: '1.0.0',
        actions: const Stream.empty(),
        onClose: () {},
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.debugShowCheckedModeBanner, isFalse);
  });

  testWidgets('the gamepad close action closes the launcher', (tester) async {
    final gamepad = StreamController<GamepadAction>.broadcast();
    var closes = 0;
    await tester.pumpWidget(
      LauncherApp(
        coreVersion: '1.0.0',
        actions: gamepad.stream,
        onClose: () => closes++,
      ),
    );

    gamepad.add(GamepadAction.close);
    await tester.pump();

    expect(closes, 1);
  });
}
