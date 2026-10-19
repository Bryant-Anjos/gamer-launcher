import 'dart:async';

/// Repete uma leitura em intervalo fixo só enquanto alguém precisa dela e
/// o launcher está visível. Cada tela que mostra o dado chama [attach] ao
/// aparecer e [detach] ao sair; nada roda com a tela escondida.
class Poller {
  Poller({required this.interval, required this.tick, this.onError});

  final Duration interval;
  final Future<void> Function() tick;
  final void Function(Object error)? onError;

  int _clients = 0;
  bool _visible = true;
  bool _busy = false;
  Timer? _timer;

  bool get isRunning => _timer != null;

  void attach() {
    _clients++;
    _update();
  }

  void detach() {
    if (_clients > 0) _clients--;
    _update();
  }

  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    _update();
  }

  void dispose() {
    _clients = 0;
    _update();
  }

  void _update() {
    final shouldRun = _clients > 0 && _visible;
    if (shouldRun == isRunning) return;
    if (!shouldRun) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer = Timer.periodic(interval, (_) => _run());
    _run();
  }

  /// Uma leitura lenta não é empilhada: o próximo intervalo é pulado.
  Future<void> _run() async {
    if (_busy) return;
    _busy = true;
    try {
      await tick();
    } catch (error) {
      onError?.call(error);
    } finally {
      _busy = false;
    }
  }
}
