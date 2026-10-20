import 'package:flutter/material.dart';
import 'package:gamer_launcher/state/launcher_controller.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/home/home_page.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/pages/apps_page.dart';
import 'package:gamer_launcher/ui/pages/files_page.dart';
import 'package:gamer_launcher/ui/pages/games_page.dart';
import 'package:gamer_launcher/ui/settings/settings_page.dart';
import 'package:gamer_launcher/ui/shell/launcher_background.dart';
import 'package:gamer_launcher/ui/shell/side_nav.dart';
import 'package:gamer_launcher/ui/shell/top_bar.dart';

/// Moldura da tela: fundo, navegação lateral, barra superior e a seção atual.
/// Só a seção visível é montada (as outras não leem nada do sistema).
class LauncherShell extends StatelessWidget {
  const LauncherShell({super.key});

  @override
  Widget build(BuildContext context) {
    final services = LauncherScope.of(context);
    return ValueListenableBuilder(
      valueListenable: services.controller,
      builder: (context, state, _) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            LauncherBackground(wallpaper: state.settings.wallpaper),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SideNav(
                  selected: state.section,
                  onSelect: services.controller.selectSection,
                  focusNodes: services.focus.nav,
                  onPower: services.openPowerMenu,
                  onEnterContent: services.enterContent,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const TopBar(),
                      Expanded(
                        child: Focus(
                          focusNode: services.focus.content,
                          child: _page(state),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _page(LauncherState state) {
    if (!state.isReady) {
      return const Center(child: CircularProgressIndicator());
    }
    final page = switch (state.section) {
      Section.home => HomePage(state: state),
      Section.apps => AppsPage(state: state),
      Section.games => GamesPage(state: state),
      Section.files => FilesPage(state: state),
      Section.settings => SettingsPage(state: state),
    };
    return Padding(
      padding: const EdgeInsets.only(top: Dimens.smallGap),
      child: KeyedSubtree(key: ValueKey(state.section), child: page),
    );
  }
}
