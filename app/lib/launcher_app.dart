import 'package:flutter/material.dart';

class LauncherApp extends StatelessWidget {
  const LauncherApp({super.key, required this.coreVersion});

  final String coreVersion;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(body: Center(child: Text('Núcleo $coreVersion'))),
    );
  }
}
