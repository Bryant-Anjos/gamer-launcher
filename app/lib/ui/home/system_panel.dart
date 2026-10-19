import 'package:flutter/material.dart';
import 'package:gamer_launcher/state/system_monitor.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/charts.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';
import 'package:gamer_launcher/ui/widgets/poller_attachment.dart';
import 'package:gamer_launcher/util/formatting.dart';

const _cpuColor = Color(0xFF3B82F6);
const _ramColor = Color(0xFF38BDF8);
const _diskColor = Color(0xFF22C55E);
const _ringSize = 34.0;
const _sparklineWidth = 96.0;
const _sparklineHeight = 28.0;
const _waitingText = '...';

/// Painel Sistema: CPU, RAM e disco com anel e histórico. Só lê o sistema
/// enquanto está na tela.
class SystemPanel extends StatelessWidget {
  const SystemPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final monitor = LauncherScope.of(context).monitor;
    return PollerAttachment(
      pollers: [monitor.poller],
      child: PanelCard(
        title: 'Sistema',
        padding: const EdgeInsets.symmetric(
          horizontal: Dimens.panelPadding,
          vertical: Dimens.gap,
        ),
        child: ValueListenableBuilder(
          valueListenable: monitor,
          builder: (context, history, _) => Column(children: _rows(history)),
        ),
      ),
    );
  }

  List<Widget> _rows(SystemHistory history) {
    final latest = history.latest;
    return [
      StatRow(
        label: 'CPU',
        value: latest == null ? _waitingText : '${latest.cpuPercent.round()}%',
        history: history.cpu,
        color: _cpuColor,
      ),
      StatRow(
        label: 'RAM',
        value: latest == null
            ? _waitingText
            : formatUsage(latest.ramUsedBytes, latest.ramTotalBytes),
        history: history.ram,
        color: _ramColor,
      ),
      StatRow(
        label: 'Disco',
        value: latest == null
            ? _waitingText
            : formatUsage(latest.diskUsedBytes, latest.diskTotalBytes),
        history: history.disk,
        color: _diskColor,
      ),
    ];
  }
}

class StatRow extends StatelessWidget {
  const StatRow({
    super.key,
    required this.label,
    required this.value,
    required this.history,
    required this.color,
  });

  final String label;
  final String value;
  final List<double> history;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        RingGauge(
          percent: history.isEmpty ? 0 : history.last,
          color: color,
          size: _ringSize,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        SizedBox(
          width: _sparklineWidth,
          height: _sparklineHeight,
          child: Sparkline(
            values: history,
            color: color,
            capacity: statsHistoryLength,
          ),
        ),
      ],
    ),
  );
}
