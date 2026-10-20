import 'package:flutter/material.dart';
import 'package:gamer_launcher/input/typing.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';
import 'package:gamer_launcher/util/formatting.dart';

const searchHint = 'Pesquisar aplicativos, arquivos, configurações...';

/// Saudação pela hora do dia, com o primeiro nome do usuário.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key, required this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    final services = LauncherScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    return ValueListenableBuilder(
      valueListenable: services.clock,
      builder: (context, now, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greetingLine(now, userName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Vamos nessa?',
            style: textTheme.titleMedium?.copyWith(
              color: LauncherPalette.of(context).textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de pesquisa da tela inicial: A, Enter ou clique abrem a pesquisa;
/// digitar com ela focada abre a pesquisa já com a letra.
class SearchField extends StatelessWidget {
  const SearchField({super.key});

  @override
  Widget build(BuildContext context) {
    final services = LauncherScope.of(context);
    final palette = LauncherPalette.of(context);
    return TypeToSearch(
      onCharacter: services.openSearch,
      child: FocusTile(
        borderRadius: Dimens.radius + Dimens.focusBorder,
        semanticLabel: 'Pesquisa',
        onActivate: () => services.openSearch(''),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(Dimens.radius),
            border: Border.all(color: palette.panelBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: palette.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  searchHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
