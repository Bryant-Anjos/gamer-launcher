/// Envia só o valor mais recente: enquanto um envio está em andamento, os
/// pedidos seguintes se substituem e só o último sai depois. Segurar o
/// direcional no volume não empilha dezenas de processos `wpctl`.
class LatestWriter {
  LatestWriter(this._send);

  final Future<void> Function(int value) _send;
  int? _next;
  Future<void>? _running;

  Future<void> submit(int value) {
    _next = value;
    return _running ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_next != null) {
        final value = _next!;
        _next = null;
        await _send(value);
      }
    } finally {
      _running = null;
    }
  }
}
