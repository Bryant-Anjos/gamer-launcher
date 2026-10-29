import 'package:flutter/material.dart';
import 'package:gamer_launcher/state/launcher_controller.dart';
import 'package:gamer_launcher/state/settings_edit.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/claude/claude_panel.dart';
import 'package:gamer_launcher/ui/home/favorites_panel.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/home/featured_cards.dart';
import 'package:gamer_launcher/ui/home/greeting_header.dart';
import 'package:gamer_launcher/ui/home/recents_panel.dart';
import 'package:gamer_launcher/ui/home/system_panel.dart';
import 'package:gamer_launcher/ui/quick/quick_controls_panel.dart';

/// Tela inicial: saudação e pesquisa no topo; à esquerda os cartões de
/// destaque e os favoritos em blocos do mesmo tamanho (navegação de TV); à
/// direita o controle rápido, o sistema e os recentes. Painel oculto some e
/// os vizinhos ocupam o espaço.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.state});

  final LauncherState state;

  bool _shows(PanelKind kind) => kind.isVisibleIn(state.settings);

  @override
  Widget build(BuildContext context) {
    final hasClaude = LauncherScope.of(context).claude != null;
    final compact =
        homeColumns(MediaQuery.sizeOf(context).width) < wideColumns;
    final body = _body(hasClaude: hasClaude, compact: compact);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Dimens.focusInset,
        Dimens.focusInset,
        Dimens.gutter,
        Dimens.gutter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          if (body != null) ...[const SizedBox(height: Dimens.gutter), body],
        ],
      ),
    );
  }

  Widget _header() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: GreetingHeader(userName: state.userName)),
      if (_shows(PanelKind.search))
        const SizedBox(width: Dimens.searchWidth, child: SearchField()),
    ],
  );

  /// Em telas estreitas a coluna da direita encolhe como um bloco só (mesmas
  /// proporções, só menor), deixando mais espaço para os cartões.
  Widget _sidePanel(Widget panels, {required bool compact}) {
    if (!compact) return SizedBox(width: Dimens.sidePanelWidth, child: panels);
    return SizedBox(
      width: Dimens.sidePanelWidth * Dimens.compactPanelScale,
      child: FittedBox(
        fit: BoxFit.fitWidth,
        alignment: Alignment.topLeft,
        child: SizedBox(width: Dimens.sidePanelWidth, child: panels),
      ),
    );
  }

  Widget? _body({required bool hasClaude, required bool compact}) {
    final left = _stack([
      if (_shows(PanelKind.featuredCards)) FeaturedCards(state: state),
      if (_shows(PanelKind.favorites))
        FavoritesPanel(favorites: state.favoriteApps),
    ]);
    final right = _stack([
      if (_shows(PanelKind.quickControls)) const QuickControlsPanel(),
      if (_shows(PanelKind.system)) const SystemPanel(),
      if (hasClaude && _shows(PanelKind.claude)) const ClaudePanel(),
      if (_shows(PanelKind.recents)) RecentsPanel(recents: state.recents),
    ]);
    if (left == null && right == null) return null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left ?? const SizedBox.shrink()),
        if (right != null) ...[
          const SizedBox(width: Dimens.gutter),
          _sidePanel(right, compact: compact),
        ],
      ],
    );
  }

  /// Painéis um embaixo do outro; nenhum visível, nada.
  Widget? _stack(List<Widget> panels) {
    if (panels.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, panel) in panels.indexed) ...[
          if (index > 0) const SizedBox(height: Dimens.gutter),
          panel,
        ],
      ],
    );
  }
}
