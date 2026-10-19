import 'package:flutter/foundation.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/state/poller.dart';

const statsInterval = Duration(seconds: 1);

/// Pontos guardados para os gráficos (30 s a 1 Hz).
const statsHistoryLength = 30;
const _fullPercent = 100.0;

double _percent(double used, double total) =>
    total <= 0 ? 0 : (used / total * _fullPercent).clamp(0, _fullPercent);

List<double> _append(List<double> values, double next, int limit) {
  final appended = [...values, next];
  final overflow = appended.length - limit;
  return List.unmodifiable(
    overflow > 0 ? appended.sublist(overflow) : appended,
  );
}

/// Últimas leituras do sistema em porcentagem, da mais antiga à mais nova.
@immutable
class SystemHistory {
  const SystemHistory({
    this.latest,
    this.cpu = const [],
    this.ram = const [],
    this.disk = const [],
  });

  final StatsSample? latest;
  final List<double> cpu;
  final List<double> ram;
  final List<double> disk;

  SystemHistory add(StatsSample sample, int limit) => SystemHistory(
    latest: sample,
    cpu: _append(cpu, sample.cpuPercent, limit),
    ram: _append(
      ram,
      _percent(sample.ramUsedBytes, sample.ramTotalBytes),
      limit,
    ),
    disk: _append(
      disk,
      _percent(sample.diskUsedBytes, sample.diskTotalBytes),
      limit,
    ),
  );
}

/// Lê CPU, RAM e disco a 1 Hz enquanto o painel Sistema estiver na tela.
class SystemMonitor extends ValueNotifier<SystemHistory> {
  SystemMonitor(this._sample, {this.onError}) : super(const SystemHistory());

  final Future<StatsSample> Function() _sample;
  final void Function(String message)? onError;
  bool _disposed = false;
  bool _reportedFailure = false;

  late final poller = Poller(
    interval: statsInterval,
    tick: _tick,
    onError: _reportOnce,
  );

  /// A leitura repete a cada segundo: avisa uma vez só, não a cada falha.
  void _reportOnce(Object error) {
    if (_reportedFailure) return;
    _reportedFailure = true;
    onError?.call('Não foi possível ler o uso do sistema: $error');
  }

  Future<void> _tick() async {
    final sample = await _sample();
    if (!_disposed) value = value.add(sample, statsHistoryLength);
  }

  @override
  void dispose() {
    _disposed = true;
    poller.dispose();
    super.dispose();
  }
}
