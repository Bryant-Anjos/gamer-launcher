import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/launcher_app.dart';

void main() {
  testWidgets('shows the core version it receives', (tester) async {
    await tester.pumpWidget(const LauncherApp(coreVersion: '9.9.9'));

    expect(find.text('Núcleo 9.9.9'), findsOneWidget);
  });

  testWidgets('does not show a debug banner', (tester) async {
    await tester.pumpWidget(const LauncherApp(coreVersion: '1.0.0'));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.debugShowCheckedModeBanner, isFalse);
  });
}
