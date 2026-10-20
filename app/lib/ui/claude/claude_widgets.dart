import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/claude.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';
import 'package:gamer_launcher/util/formatting.dart';

const _statWidth = 150.0;
const _barsHeight = 110.0;
const _barRadius = 4.0;
const _barGapFraction = 0.35;
const _statusDot = 10.0;

String _statusLabel(ClaudeSessionStatus status) => switch (status) {
  ClaudeSessionStatus.busy => 'Trabalhando',
  ClaudeSessionStatus.idle => 'Esperando você',
  ClaudeSessionStatus.other => 'Aberta',
};

/// "13/10" a partir de "2026-10-13".
String dayMonth(String isoDate) => isoDate.length < 10
    ? isoDate
    : '${isoDate.substring(8, 10)}/${isoDate.substring(5, 7)}';

/// Bloco focável (sem ação) com a superfície dos painéis: o controle anda
/// por eles e a página rola junto.
class ClaudeBlock extends StatelessWidget {
  const ClaudeBlock({super.key, required this.child, this.semanticLabel});

  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => FocusTile(
    focusable: true,
    semanticLabel: semanticLabel,
    child: Container(
      color: LauncherPalette.of(context).panel,
      padding: const EdgeInsets.all(Dimens.panelPadding),
      child: child,
    ),
  );
}

/// Uma sessão aberta: projeto, título, estado, modelo, branch e agentes.
class SessionCard extends StatelessWidget {
  const SessionCard({super.key, required this.session, required this.now});

  final ClaudeSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    final busy = session.status == ClaudeSessionStatus.busy;
    final title = session.title;
    final details = [
      ?session.model,
      if (session.branch case final branch?) 'branch $branch',
      if (session.startedMs case final started?)
        'aberta ${formatSince(started, now)}',
    ];
    return ClaudeBlock(
      semanticLabel: '${session.project}: ${_statusLabel(session.status)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: _statusDot,
                height: _statusDot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: busy ? palette.accent : palette.textMuted,
                ),
              ),
              const SizedBox(width: Dimens.smallGap),
              Expanded(
                child: Text(
                  session.project,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              MutedText(_statusLabel(session.status)),
            ],
          ),
          if (title != null) Text(title, maxLines: 1),
          if (details.isNotEmpty) MutedText(details.join(' · ')),
          for (final agent in session.agents) ...[
            const SizedBox(height: Dimens.smallGap),
            AgentLine(agent: agent, now: now),
          ],
        ],
      ),
    );
  }
}

/// Um subagente: tipo, descrição curta e se ainda trabalha.
class AgentLine extends StatelessWidget {
  const AgentLine({super.key, required this.agent, required this.now});

  final ClaudeAgent agent;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    final state = agent.running
        ? 'trabalhando'
        : 'parado ${formatSince(agent.lastActivityMs, now)}'.trim();
    return Row(
      children: [
        Icon(
          agent.running ? Icons.bolt_rounded : Icons.check_rounded,
          size: Dimens.statusIcon,
          color: agent.running ? palette.accent : palette.textMuted,
        ),
        const SizedBox(width: Dimens.smallGap),
        Expanded(
          child: Text(
            [
              agent.agentType,
              agent.description,
            ].where((part) => part.isNotEmpty).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Dimens.smallGap),
        MutedText(state),
      ],
    );
  }
}

/// Número grande com o rótulo embaixo.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _statWidth,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        MutedText(label),
      ],
    ),
  );
}

/// Os números de um período (hoje ou a semana).
class TotalsRow extends StatelessWidget {
  const TotalsRow({super.key, required this.totals});

  final ClaudeTotals totals;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Dimens.gap,
    runSpacing: Dimens.gap,
    children: [
      StatTile(value: formatCompact(totals.replies), label: 'respostas'),
      StatTile(value: formatCompact(totals.toolCalls), label: 'ferramentas'),
      StatTile(value: formatCompact(totals.sessions), label: 'sessões'),
      StatTile(
        value: formatCompact(totals.inputTokens),
        label: 'tokens de entrada',
      ),
      StatTile(
        value: formatCompact(totals.outputTokens),
        label: 'tokens de saída',
      ),
    ],
  );
}

/// Barras de respostas por dia, com a data embaixo.
class DayBars extends StatelessWidget {
  const DayBars({super.key, required this.days});

  final List<ClaudeDayPoint> days;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    return Column(
      children: [
        SizedBox(
          height: _barsHeight,
          width: double.infinity,
          child: CustomPaint(
            painter: _BarsPainter([
              for (final day in days) day.replies.toDouble(),
            ], palette.accent),
          ),
        ),
        const SizedBox(height: Dimens.tinyGap),
        Row(
          children: [
            for (final day in days)
              Expanded(child: Center(child: MutedText(dayMonth(day.date)))),
          ],
        ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final highest = values.reduce((a, b) => a > b ? a : b);
    if (highest <= 0) return;
    final slot = size.width / values.length;
    final width = slot * (1 - _barGapFraction);
    final paint = Paint()..color = color;
    for (final (index, value) in values.indexed) {
      final height = value / highest * size.height;
      final left = index * slot + (slot - width) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, width, height),
          const Radius.circular(_barRadius),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.color != color || old.values != values;
}
