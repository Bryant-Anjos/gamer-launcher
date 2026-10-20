import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamer_launcher/backend/rust_backend.dart';
import 'package:gamer_launcher/input/gamepad_stream.dart';
import 'package:gamer_launcher/launcher_app.dart';
import 'package:gamer_launcher/src/rust/api/meta.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/src/rust/frb_generated.dart';

/// Layout salvo, para o controle já começar certo. Configurações que não
/// abrem ficam no automático; o app avisa do erro ao carregá-las de novo.
Future<LauncherButtonLayout> _savedButtonLayout() async {
  try {
    return (await loadSettings()).buttonLayout;
  } on Object {
    return LauncherButtonLayout.auto;
  }
}

Future<void> main() async {
  await RustLib.init();
  final layout = await _savedButtonLayout();
  runApp(
    LauncherApp(
      backend: const RustBackend(),
      coreVersion: coreVersion(),
      actions: gamepadStream(layout: layout),
      onClose: SystemNavigator.pop,
    ),
  );
}
