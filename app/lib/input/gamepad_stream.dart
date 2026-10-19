import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';

/// Ações do controle com ciclo de vida: a leitura em Rust começa quando
/// alguém passa a ouvir e é parada quando deixa de ouvir. Sem leitura de
/// controles (sem udev, por exemplo) o stream só fica quieto, e o launcher
/// segue por teclado e mouse.
Stream<GamepadAction> gamepadStream({
  Stream<GamepadAction> Function() start = gamepadActions,
  void Function() stop = gamepadStop,
}) {
  late final StreamController<GamepadAction> controller;
  StreamSubscription<GamepadAction>? source;
  controller = StreamController<GamepadAction>(
    onListen: () {
      source = start().listen(
        controller.add,
        onError: (Object error) => debugPrint('Controle indisponível: $error'),
      );
    },
    onCancel: () async {
      await source?.cancel();
      stop();
    },
  );
  return controller.stream;
}
