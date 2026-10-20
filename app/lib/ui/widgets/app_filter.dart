import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gamer_launcher/input/typing.dart';
import 'package:gamer_launcher/src/rust/api/catalog.dart';
import 'package:gamer_launcher/src/rust/api/search.dart';
import 'package:gamer_launcher/state/search_model.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';
import 'package:gamer_launcher/ui/widgets/search_input.dart';

/// Todos os apps cabem no filtro (a busca do núcleo corta no limite).
const _filterLimit = 500;
const noAppsFoundText = 'Nenhum aplicativo com esse nome.';

/// Campo "Filtrar pelo nome" sobre uma lista de apps (seletor de favoritos,
/// seção Aplicativos). Usa a pesquisa do núcleo restrita a apps, e não um
/// filtro local, para achar igual à pesquisa global: sem acentos, sem
/// maiúsculas e por sigla ("vsc"). Digitar com um app focado leva a letra
/// ao campo; Enter (ou A no campo) chama [onSubmit] com o primeiro achado.
class AppFilter extends StatefulWidget {
  const AppFilter({
    super.key,
    required this.apps,
    required this.builder,
    required this.onSubmit,
    this.leading,
    this.fieldWidth,
    this.headerPadding = EdgeInsets.zero,
  });

  final List<AppInfo> apps;
  final Widget Function(BuildContext context, List<AppInfo> visible) builder;
  final ValueChanged<AppInfo> onSubmit;

  /// À esquerda do campo, na mesma linha (o título da página).
  final Widget? leading;

  /// Sem largura, o campo ocupa a linha toda.
  final double? fieldWidth;

  /// Recuo da linha do campo (a página deixa a margem da direita).
  final EdgeInsets headerPadding;

  @override
  State<AppFilter> createState() => _AppFilterState();
}

class _AppFilterState extends State<AppFilter> {
  final _text = TextEditingController();
  final _field = FocusNode(debugLabel: 'app-filter');
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

  void _typeInFilter(String character) {
    final text = _text.text + character;
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _field.requestFocus();
    unawaited(filter.setQuery(text));
  }

  List<AppInfo> _visible(SearchState found) {
    if (found.isEmptyQuery) return widget.apps;
    final byId = {for (final app in widget.apps) app.id: app};
    return [for (final result in found.results) ?byId[result.appId]];
  }

  Widget _input(List<AppInfo> visible) => SearchInput(
    controller: _text,
    focusNode: _field,
    hint: 'Filtrar pelo nome',
    onChanged: filter.setQuery,
    onSubmit: () {
      if (visible.isNotEmpty) widget.onSubmit(visible.first);
    },
  );

  Widget _header(List<AppInfo> visible) {
    final leading = widget.leading;
    final width = widget.fieldWidth;
    if (leading == null && width == null) return _input(visible);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: leading ?? const SizedBox.shrink()),
        SizedBox(width: width, child: _input(visible)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: filter,
    builder: (context, found, _) {
      final visible = _visible(found);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: widget.headerPadding, child: _header(visible)),
          const SizedBox(height: Dimens.gap),
          Expanded(
            child: visible.isEmpty
                ? const MutedText(noAppsFoundText)
                : TypeToSearch(
                    onCharacter: _typeInFilter,
                    child: widget.builder(context, visible),
                  ),
          ),
        ],
      );
    },
  );
}
