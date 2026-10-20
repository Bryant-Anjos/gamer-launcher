import 'package:flutter/material.dart';
import 'package:gamer_launcher/state/launcher_controller.dart';
import 'package:gamer_launcher/state/settings_edit.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/home/favorites_panel.dart';
import 'package:gamer_launcher/ui/home/featured_cards.dart';
import 'package:gamer_launcher/ui/home/greeting_header.dart';
import 'package:gamer_launcher/ui/home/recents_panel.dart';
import 'package:gamer_launcher/ui/home/system_panel.dart';
import 'package:gamer_launcher/ui/quick/quick_controls_panel.dart';

const _favoritesFlex = 5;
const _recentsFlex = 4;

/// Tela inicial na disposição da arte: saudação e pesquisa no topo,
/// cartões e controle rápido, depois favoritos, recentes e sistema. Painel
/// oculto some e os vizinhos ocupam o espaço.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.state});

  final LauncherState state;

  bool _shows(PanelKind kind) => kind.isVisibleIn(state.settings);

  @override
  Widget build(BuildContext context) {
    final rows = [
      _header(),
      _topRow(),
      _bottomRow(),
    ].whereType<Widget>().toList();
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
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) const SizedBox(height: Dimens.gutter),
            row,
          ],
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

  Widget? _topRow() {
    final cards = _shows(PanelKind.featuredCards);
    final quick = _shows(PanelKind.quickControls);
    if (!cards && !quick) return null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: cards ? FeaturedCards(state: state) : const SizedBox()),
        if (quick) ...[
          const SizedBox(width: Dimens.gutter),
          const SizedBox(
            width: Dimens.sidePanelWidth,
            child: QuickControlsPanel(),
          ),
        ],
      ],
    );
  }

  Widget? _bottomRow() {
    final favorites = _shows(PanelKind.favorites);
    final recents = _shows(PanelKind.recents);
    final system = _shows(PanelKind.system);
    if (!favorites && !recents && !system) return null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (favorites)
          Expanded(
            flex: _favoritesFlex,
            child: FavoritesPanel(favorites: state.favoriteApps),
          ),
        if (favorites && recents) const SizedBox(width: Dimens.gutter),
        if (recents)
          Expanded(
            flex: _recentsFlex,
            child: RecentsPanel(recents: state.recents),
          ),
        if (!favorites && !recents) const Spacer(),
        if (system) ...[
          const SizedBox(width: Dimens.gutter),
          const SizedBox(width: Dimens.sidePanelWidth, child: SystemPanel()),
        ],
      ],
    );
  }
}
