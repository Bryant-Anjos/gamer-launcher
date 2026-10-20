import 'package:flutter/foundation.dart';
import 'package:gamer_launcher/backend/launcher_backend.dart';
import 'package:gamer_launcher/src/rust/api/claude.dart';
import 'package:gamer_launcher/state/poller.dart';

/// Sessões e agentes mudam a todo instante; uma leitura é barata (registro
/// pequeno e só o fim do transcrito).
const claudeNowInterval = Duration(seconds: 5);

/// O uso lê os transcritos aos poucos; um minuto basta para "hoje".
const claudeStatsInterval = Duration(minutes: 1);

/// O que a tela mostra do Claude Code; vazio até a primeira leitura.
@immutable
class ClaudeState {
  const ClaudeState({this.now, this.stats});

  final ClaudeNow? now;
  final ClaudeStats? stats;

  int get busySessions =>
      now?.sessions.where((s) => s.status == ClaudeSessionStatus.busy).length ??
      0;

  int get runningAgents => [
    for (final session in now?.sessions ?? const <ClaudeSession>[])
      ...session.agents.where((agent) => agent.running),
  ].length;

  ClaudeState copyWith({ClaudeNow? now, ClaudeStats? stats}) =>
      ClaudeState(now: now ?? this.now, stats: stats ?? this.stats);
}

/// Acompanhamento do Claude Code. Só existe com ele instalado, e só lê com
/// o painel ou a seção na tela e o launcher visível. Falha de leitura não
/// aparece: o formato do Claude muda sem aviso, então fica o último valor.
class ClaudeController extends ValueNotifier<ClaudeState> {
  ClaudeController(this._backend, {required DateTime Function() now})
    : _clock = now,
      super(const ClaudeState());

  final LauncherBackend _backend;
  final DateTime Function() _clock;
  bool _disposed = false;

  late final nowPoller = Poller(interval: claudeNowInterval, tick: _readNow);
  late final statsPoller = Poller(
    interval: claudeStatsInterval,
    tick: _readStats,
  );

  List<Poller> get pollers => [nowPoller, statsPoller];

  void attach() {
    for (final poller in pollers) {
      poller.attach();
    }
  }

  void detach() {
    for (final poller in pollers) {
      poller.detach();
    }
  }

  @override
  set value(ClaudeState next) {
    if (!_disposed) super.value = next;
  }

  Future<void> _readNow() async {
    try {
      value = value.copyWith(now: await _backend.readClaudeNow());
    } on BackendException {
      // mantém o último valor
    }
  }

  Future<void> _readStats() async {
    final time = _clock();
    try {
      final stats = await _backend.readClaudeStats(
        time.millisecondsSinceEpoch,
        time.timeZoneOffset.inMinutes,
      );
      value = value.copyWith(stats: stats);
    } on BackendException {
      // mantém o último valor
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final poller in pollers) {
      poller.dispose();
    }
    super.dispose();
  }
}
