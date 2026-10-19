import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/launcher_app.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';

import 'fake_backend.dart';

/// Tela cheia típica (a do notebook do Bryant).
const fullHd = Size(1920, 1080);

/// Mesmo horário da arte de conceito: quinta, 16 de outubro, 19:42.
final conceptTime = DateTime(2026, 10, 16, 19, 42);

class LauncherHarness {
  LauncherHarness(this.backend);

  final FakeBackend backend;
  final pad = StreamController<GamepadAction>.broadcast();
  int closes = 0;

  /// Aperta um botão e deixa a tela reagir (o evento chega depois do
  /// primeiro frame).
  Future<void> press(WidgetTester tester, GamepadAction action) async {
    pad.add(action);
    await tester.pump();
    await tester.pump();
  }

  Future<void> pressAndSettle(WidgetTester tester, GamepadAction action) async {
    await press(tester, action);
    await tester.pumpAndSettle();
  }
}

Future<LauncherHarness> pumpLauncher(
  WidgetTester tester, {
  FakeBackend? backend,
  Size size = fullHd,
  DateTime? now,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = LauncherHarness(backend ?? FakeBackend());
  final time = now ?? conceptTime;
  await tester.pumpWidget(
    LauncherApp(
      backend: harness.backend,
      actions: harness.pad.stream,
      onClose: () => harness.closes++,
      coreVersion: '0.1.0',
      now: () => time,
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

/// O item que contém [finder] (texto, ícone...) tem o foco primário?
bool hasFocus(WidgetTester tester, Finder finder) =>
    Focus.of(tester.element(finder)).hasPrimaryFocus;

/// Roboto e os ícones do Material vindos do próprio SDK, para os goldens
/// mostrarem texto e ícones de verdade em vez de blocos.
Future<void> loadLauncherFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('$dir/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}
