import 'dart:async';

/// Avisos curtos para o usuário (abrir app falhou, configuração inválida).
/// O app mostra cada um como SnackBar; os controladores só publicam.
class LauncherMessages {
  final _controller = StreamController<String>.broadcast();

  Stream<String> get stream => _controller.stream;

  void show(String message) {
    if (!_controller.isClosed) _controller.add(message);
  }

  Future<void> dispose() => _controller.close();
}
