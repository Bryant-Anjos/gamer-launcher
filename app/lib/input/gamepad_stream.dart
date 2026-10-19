import 'dart:async';

import 'package:gamer_launcher/src/rust/api/input.dart';

/// O sistema não deixou ler controles (sem udev, sem permissão...). O
/// launcher segue por teclado e mouse; a tela avisa uma vez.
class GamepadUnavailable implements Exception {
  const GamepadUnavailable(this.reason);

  final Object reason;

  @override
  String toString() => 'Controle indisponível: $reason';
}

/// Ações do controle com ciclo de vida: a leitura em Rust começa quando
/// alguém passa a ouvir e é parada quando deixa de ouvir. Uma falha da
/// leitura chega a quem ouve como um único [GamepadUnavailable].
Stream<GamepadAction> gamepadStream({
  Stream<GamepadAction> Function() start = gamepadActions,
  void Function() stop = gamepadStop,
}) {
  late final StreamController<GamepadAction> controller;
  StreamSubscription<GamepadAction>? source;
  var reported = false;
  void report(Object error) {
    if (reported) return;
    reported = true;
    controller.addError(GamepadUnavailable(error));
  }

  controller = StreamController<GamepadAction>(
    onListen: () {
      try {
        source = start().listen(controller.add, onError: report);
      } catch (error) {
        report(error);
      }
    },
    onCancel: () async {
      await source?.cancel();
      stop();
    },
  );
  return controller.stream;
}
