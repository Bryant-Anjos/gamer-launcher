import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gamer_launcher/input/button_names.dart';
import 'package:gamer_launcher/input/typing.dart';
import 'package:gamer_launcher/src/rust/api/search.dart';
import 'package:gamer_launcher/state/launcher_controller.dart';
import 'package:gamer_launcher/state/search_model.dart';
import 'package:gamer_launcher/src/rust/api/catalog.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/app_icon.dart';
import 'package:gamer_launcher/ui/widgets/button_hints.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';
import 'package:gamer_launcher/ui/widgets/overlay_card.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';
import 'package:gamer_launcher/ui/widgets/search_input.dart';

const _pickerWidthFactor = 0.7;
const _pickerHeightFactor = 0.8;
const _checkSize = 22.0;

/// Todos os apps cabem no filtro (a busca do núcleo corta no limite).
const _filterLimit = 500;
const noAppsFoundText = 'Nenhum aplicativo com esse nome.';

/// Escolha dos favoritos: todos os apps, com marca nos favoritos. A
/// marca/desmarca; B fecha. Fica num diálogo por cima da tela inicial.
///
/// O filtro usa a pesquisa do núcleo restrita a apps (e não um filtro local)
/// para achar do mesmo jeito que a pesquisa global: sem acentos, sem
/// maiúsculas e por sigla ("vsc" acha o VS Code).
class FavoritesPicker extends StatefulWidget {
  const FavoritesPicker({super.key});

  @override
  State<FavoritesPicker> createState() => _FavoritesPickerState();
}

class _FavoritesPickerState extends State<FavoritesPicker> {
  final _text = TextEditingController();
  final _field = FocusNode(debugLabel: 'favorites-filter');
  SearchModel? _filter;

  SearchModel get filter => _filter!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filter != null) return;
    final services = LauncherScope.of(context);
    _filter = SearchModel(
      services.backend,
      services.messages,
      limit: _filterLimit,
      kinds: const {SearchKind.app},
    );
  }

  @override
  void dispose() {
    _filter?.dispose();
    _text.dispose();
    _field.dispose();
    super.dispose();
  }

  /// Digitar com um app focado leva a letra para o filtro.
  void _typeInFilter(String character) {
    _text.value = TextEditingValue(
      text: _text.text + character,
      selection: TextSelection.collapsed(
        offset: _text.text.length + character.length,
      ),
    );
    _field.requestFocus();
    unawaited(filter.setQuery(_text.text));
  }

  List<AppInfo> _visible(LauncherState state, SearchState found) {
    if (found.isEmptyQuery) return state.catalog.apps;
    return found.results
        .map((result) => state.appById(result.appId))
        .whereType<AppInfo>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final services = LauncherScope.of(context);
    final size = MediaQuery.sizeOf(context);
    return OverlayCard(
      title: 'Escolha os favoritos',
      hint: const ButtonHints([
        ButtonHint(PadRole.confirm, 'marca ou desmarca'),
        ButtonHint(PadRole.back, 'fecha'),
      ]),
      width: size.width * _pickerWidthFactor,
      height: size.height * _pickerHeightFactor,
      child: ListenableBuilder(
        listenable: Listenable.merge([services.controller, filter]),
        builder: (context, _) {
          final state = services.controller.value;
          final apps = _visible(state, filter.value);
          void toggle(AppInfo app) =>
              services.controller.toggleFavorite(app.id);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchInput(
                controller: _text,
                focusNode: _field,
                hint: 'Filtrar pelo nome',
                onChanged: filter.setQuery,
                onSubmit: () {
                  if (apps.isNotEmpty) toggle(apps.first);
                },
              ),
              const SizedBox(height: Dimens.gap),
              Expanded(
                child: apps.isEmpty
                    ? const MutedText(noAppsFoundText)
                    : TypeToSearch(
                        onCharacter: _typeInFilter,
                        child: _PickerGrid(
                          apps: apps,
                          favorites: state.settings.favorites,
                          onToggle: toggle,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PickerGrid extends StatelessWidget {
  const _PickerGrid({
    required this.apps,
    required this.favorites,
    required this.onToggle,
  });

  final List<AppInfo> apps;
  final List<String> favorites;
  final ValueChanged<AppInfo> onToggle;

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(Dimens.smallGap),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: Dimens.appGridExtent,
      mainAxisSpacing: Dimens.gap,
      crossAxisSpacing: Dimens.gap,
    ),
    itemCount: apps.length,
    itemBuilder: (context, index) {
      final app = apps[index];
      return PickerTile(
        app: app,
        isFavorite: favorites.contains(app.id),
        autofocus: index == 0,
        onToggle: () => onToggle(app),
      );
    },
  );
}

class PickerTile extends StatelessWidget {
  const PickerTile({
    super.key,
    required this.app,
    required this.isFavorite,
    required this.onToggle,
    this.autofocus = false,
  });

  final AppInfo app;
  final bool isFavorite;
  final VoidCallback onToggle;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    return FocusTile(
      autofocus: autofocus,
      semanticLabel: '${app.name}${isFavorite ? ', favorito' : ''}',
      onActivate: onToggle,
      child: Container(
        color: isFavorite
            ? palette.accent.withValues(alpha: Opacities.selected)
            : palette.tile,
        padding: const EdgeInsets.all(Dimens.smallGap),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
            if (isFavorite)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: palette.accent,
                  size: _checkSize,
                  semanticLabel: 'Favorito',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
