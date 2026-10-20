import 'package:flutter/material.dart';
import 'package:gamer_launcher/state/claude_controller.dart';
import 'package:gamer_launcher/state/launcher_controller.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/menu_row.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';
import 'package:gamer_launcher/ui/widgets/poller_attachment.dart';
import 'package:gamer_launcher/util/formatting.dart';

/// "2 sessões abertas · 1 trabalhando".
String claudeSessionsLine(ClaudeState state) {
  final open = state.now?.sessions.length ?? 0;
  if (open == 0) return 'Nenhuma sessão aberta';
  final sessions = open == 1 ? '1 sessão aberta' : '$open sessões abertas';
  final busy = state.busySessions;
  return busy == 0 ? sessions : '$sessions · $busy trabalhando';
}

/// Resumo do Claude Code na tela inicial: sessões abertas, agentes
/// trabalhando e o uso de hoje; "Ver detalhes" leva à seção Claude. Só
/// existe com o Claude instalado.
class ClaudePanel extends StatelessWidget {
  const ClaudePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final services = LauncherScope.of(context);
    final claude = services.claude;
    if (claude == null) return const SizedBox.shrink();
    return PollerAttachment(
      pollers: claude.pollers,
      child: PanelCard(
        title: 'Claude Code',
        child: ValueListenableBuilder(
          valueListenable: claude,
          builder: (context, state, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._summary(context, state),
              const SizedBox(height: Dimens.gap),
              MenuRow(
                icon: Icons.terminal_rounded,
                label: 'Ver detalhes',
                background: LauncherPalette.of(context).tile,
                onActivate: () =>
                    services.controller.selectSection(Section.claude),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _summary(BuildContext context, ClaudeState state) {
    final agents = state.runningAgents;
    final today = state.stats?.today;
    final first = state.now?.sessions.firstOrNull;
    return [
      Text(
        claudeSessionsLine(state),
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      if (first != null) MutedText([first.project, ?first.title].join(' · ')),
      if (agents > 0)
        Text(
          agents == 1 ? '1 agente trabalhando' : '$agents agentes trabalhando',
        ),
      if (today != null)
        MutedText(
          'Hoje: ${formatCompact(today.replies)} respostas · '
          '${formatCompact(today.toolCalls)} ferramentas · '
          '${formatCompact(today.inputTokens + today.outputTokens)} tokens',
          maxLines: 2,
        ),
    ];
  }
}
