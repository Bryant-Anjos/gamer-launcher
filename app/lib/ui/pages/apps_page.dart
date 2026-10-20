import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/catalog.dart';
import 'package:gamer_launcher/state/launcher_controller.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/pages/page_header.dart';
import 'package:gamer_launcher/ui/widgets/app_icon.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';

const noAppsText = 'Nenhum aplicativo encontrado.';

/// Todos os apps em grade. A grade é preguiçosa: só os itens visíveis
/// são montados, e os ícones carregam conforme aparecem.
class AppsPage extends StatelessWidget {
  const AppsPage({super.key, required this.state});

  final LauncherState state;

  @override
  Widget build(BuildContext context) {
    final controller = LauncherScope.of(context).controller;
    final apps = state.catalog.apps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(title: 'Aplicativos', subtitle: '${apps.length} instalados'),
        Expanded(
          child: apps.isEmpty
              ? const EmptyState(icon: Icons.apps_rounded, text: noAppsText)
              : AppGrid(
                  apps: apps,
                  onActivate: (app) => controller.launchApp(app.id),
                ),
        ),
      ],
    );
  }
}

class AppGrid extends StatelessWidget {
  const AppGrid({super.key, required this.apps, required this.onActivate});

  final List<AppInfo> apps;
  final ValueChanged<AppInfo> onActivate;

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(
      Dimens.focusInset,
      Dimens.focusInset,
      Dimens.gutter,
      Dimens.gutter,
    ),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: Dimens.appGridExtent,
      mainAxisSpacing: Dimens.gap,
      crossAxisSpacing: Dimens.gap,
    ),
    itemCount: apps.length,
    itemBuilder: (context, index) =>
        AppTile(app: apps[index], onActivate: () => onActivate(apps[index])),
  );
}

class AppTile extends StatelessWidget {
  const AppTile({super.key, required this.app, required this.onActivate});

  final AppInfo app;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) => FocusTile(
    semanticLabel: app.name,
    onActivate: onActivate,
    child: Container(
      color: LauncherPalette.of(context).panel,
      padding: const EdgeInsets.all(Dimens.smallGap),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(
            name: app.name,
            iconPath: app.iconPath,
            size: Dimens.appGridIcon,
          ),
          const SizedBox(height: Dimens.smallGap),
          Text(
            app.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}
