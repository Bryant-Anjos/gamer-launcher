import 'package:flutter/material.dart';
import 'package:gamer_launcher/state/launcher_controller.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/pages/apps_page.dart';
import 'package:gamer_launcher/ui/pages/page_header.dart';

const noLaunchersText =
    'Nenhum lançador de jogos encontrado. Instale a Steam, o Heroic ou o '
    'Lutris para abrir a sua biblioteca daqui.';

/// Jogos: só atalhos para os lançadores instalados (sem biblioteca própria).
class GamesPage extends StatelessWidget {
  const GamesPage({super.key, required this.state});

  final LauncherState state;

  @override
  Widget build(BuildContext context) {
    final controller = LauncherScope.of(context).controller;
    final launchers = state.gameLaunchers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Jogos',
          subtitle: 'Abra a biblioteca no seu lançador',
        ),
        if (launchers.isEmpty)
          const EmptyState(
            icon: Icons.sports_esports_rounded,
            text: noLaunchersText,
          )
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: Dimens.gutter),
              child: AppGrid(
                apps: launchers,
                onActivate: (app) => controller.launchApp(app.id),
              ),
            ),
          ),
      ],
    );
  }
}
