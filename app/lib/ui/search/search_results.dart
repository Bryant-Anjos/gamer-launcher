import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/search.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/app_icon.dart';
import 'package:gamer_launcher/ui/widgets/menu_row.dart';

const _resultIcon = 28.0;

String _kindLabel(SearchKind kind) => switch (kind) {
  SearchKind.app => 'Aplicativo',
  SearchKind.file => 'Arquivo recente',
  SearchKind.setting => 'Configurações do sistema',
};

IconData _kindIcon(SearchKind kind) => switch (kind) {
  SearchKind.app => Icons.apps_rounded,
  SearchKind.file => Icons.insert_drive_file_rounded,
  SearchKind.setting => Icons.settings_rounded,
};

/// Resultados da pesquisa: ícone (o do app, quando é app), título e de onde
/// vem (a pasta, para arquivos). A ou Enter abrem.
class SearchResultsList extends StatelessWidget {
  const SearchResultsList({
    super.key,
    required this.results,
    required this.onOpen,
  });

  final List<SearchResult> results;
  final ValueChanged<SearchResult> onOpen;

  @override
  Widget build(BuildContext context) => ListView.separated(
    // espaço para o anel de foco não ser cortado nas bordas
    padding: const EdgeInsets.all(Dimens.smallGap),
    itemCount: results.length,
    separatorBuilder: (_, _) => const SizedBox(height: Dimens.smallGap),
    itemBuilder: (context, index) {
      final result = results[index];
      return _ResultRow(result: result, onOpen: () => onOpen(result));
    },
  );
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result, required this.onOpen});

  final SearchResult result;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final state = LauncherScope.of(context).controller.value;
    final app = state.appById(result.appId);
    final kind = _kindLabel(result.kind);
    return MenuRow(
      icon: _kindIcon(result.kind),
      leading: app == null
          ? Icon(
              _kindIcon(result.kind),
              size: _resultIcon,
              color: LauncherPalette.of(context).textMuted,
            )
          : AppIcon(name: app.name, iconPath: app.iconPath, size: _resultIcon),
      label: result.title,
      subtitle: result.subtitle ?? kind,
      semanticLabel: '${result.title}, $kind',
      onActivate: onOpen,
    );
  }
}
