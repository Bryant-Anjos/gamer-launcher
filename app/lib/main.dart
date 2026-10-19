import 'package:flutter/material.dart';
import 'package:gamer_launcher/launcher_app.dart';
import 'package:gamer_launcher/src/rust/api/meta.dart';
import 'package:gamer_launcher/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(LauncherApp(coreVersion: coreVersion()));
}
