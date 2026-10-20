import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/claude.dart';
import 'package:gamer_launcher/state/claude_controller.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/claude/claude_widgets.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/pages/page_header.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';
import 'package:gamer_launcher/ui/widgets/poller_attachment.dart';
import 'package:gamer_launcher/util/formatting.dart';

const noClaudeSessionsText = 'Nenhuma sessão do Claude Code aberta agora.';
const _readingText = 'Lendo...';

/// Seção Claude: sessões abertas agora (com agentes), uso de hoje e da
/// semana e o histórico que o próprio Claude calcula. Só leitura.
class ClaudePage extends StatelessWidget {
  const ClaudePage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = LauncherScope.of(context);
    final claude = services.claude;
    if (claude == null) return const SizedBox.shrink();
    return PollerAttachment(
      pollers: claude.pollers,
      child: ListenableBuilder(
        listenable: Listenable.merge([claude, services.clock]),
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Dimens.focusInset,
                0,
                Dimens.gutter,
                Dimens.gutter,
              ),
              sliver: SliverList.list(
                children: _children(claude.value, services.clock.value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _children(ClaudeState state, DateTime now) {
    final version = state.now?.version;
    final stats = state.stats;
    return [
      PageHeader(
        title: 'Claude Code',
        subtitle: [
          if (version != null) 'Versão $version',
          'só leitura',
        ].join(' · '),
        inset: 0,
      ),
      const SectionTitle('Agora'),
      ..._sessions(state.now, now),
      const SizedBox(height: Dimens.gutter),
      const SectionTitle('Hoje'),
      if (stats == null) const MutedText(_readingText) else _today(stats),
      const SizedBox(height: Dimens.gutter),
      const SectionTitle('Últimos 7 dias'),
      if (stats != null) _week(stats),
      if (stats?.history case final history?) ...[
        const SizedBox(height: Dimens.gutter),
        const SectionTitle('Histórico'),
        _history(history),
      ],
    ];
  }

  List<Widget> _sessions(ClaudeNow? now, DateTime time) {
    if (now == null) return const [MutedText(_readingText)];
    if (now.sessions.isEmpty) return const [MutedText(noClaudeSessionsText)];
    return [
      for (final (index, session) in now.sessions.indexed) ...[
        if (index > 0) const SizedBox(height: Dimens.smallGap),
        SessionCard(session: session, now: time),
      ],
    ];
  }

  Widget _today(ClaudeStats stats) => ClaudeBlock(
    semanticLabel: 'Uso de hoje',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TotalsRow(totals: stats.today),
        for (final model in stats.todayModels)
          Padding(
            padding: const EdgeInsets.only(top: Dimens.smallGap),
            child: MutedText(
              '${model.model}: ${formatCompact(model.inputTokens)} de entrada'
              ' · ${formatCompact(model.outputTokens)} de saída',
            ),
          ),
      ],
    ),
  );

  Widget _week(ClaudeStats stats) => ClaudeBlock(
    semanticLabel: 'Uso dos últimos 7 dias',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TotalsRow(totals: stats.week),
        const SizedBox(height: Dimens.gap),
        const MutedText('Respostas por dia'),
        const SizedBox(height: Dimens.smallGap),
        DayBars(days: stats.days),
      ],
    ),
  );

  Widget _history(ClaudeHistory history) {
    final period = [
      if (history.since case final since?) 'de ${dayMonth(since)}',
      if (history.until case final until?) 'a ${dayMonth(until)}',
    ].join(' ');
    final totals = [
      if (history.sessions case final sessions?)
        '${formatCompact(sessions)} sessões',
      if (history.messages case final messages?)
        '${formatCompact(messages)} mensagens',
    ].join(', ');
    return ClaudeBlock(
      semanticLabel: 'Histórico',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text([period, totals].where((p) => p.isNotEmpty).join(': ')),
          const MutedText(
            'Totais calculados pelo próprio Claude Code; podem estar alguns '
            'dias atrasados.',
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
