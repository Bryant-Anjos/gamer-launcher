import 'package:flutter/material.dart';
import 'package:gamer_launcher/input/input_router.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';

class LauncherApp extends StatelessWidget {
  const LauncherApp({
    super.key,
    required this.coreVersion,
    required this.actions,
    required this.onClose,
  });

  final String coreVersion;
  final Stream<GamepadAction> actions;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: InputRouter(
        actions: actions,
        onClose: onClose,
        child: Scaffold(body: Center(child: Text('Núcleo $coreVersion'))),
      ),
    );
  }
}
