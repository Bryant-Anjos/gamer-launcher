import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gamer_launcher/input/button_names.dart';
import 'package:gamer_launcher/src/rust/api/search.dart';
import 'package:gamer_launcher/state/search_model.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/search/search_results.dart';
import 'package:gamer_launcher/ui/widgets/button_hints.dart';
import 'package:gamer_launcher/ui/widgets/overlay_card.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';
import 'package:gamer_launcher/ui/widgets/search_input.dart';

const searchEmptyText =
    'Digite para pesquisar aplicativos, arquivos e configurações.';
const _heightFactor = 0.75;

String searchNothingFound(String query) => 'Nada encontrado para "$query".';

/// Pesquisa global por cima de qualquer seção (botão Y ou a barra da tela
/// inicial). O campo já vem focado; para baixo vai aos resultados; A ou
/// Enter abrem; B fecha.
class SearchOverlay extends StatefulWidget {
  const SearchOverlay({super.key, this.initialText = ''});

  /// Letra já digitada na barra da tela inicial.
  final String initialText;

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  late final _text = TextEditingController(text: widget.initialText);
  SearchModel? _model;

  SearchModel get model => _model!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_model != null) return;
    final services = LauncherScope.of(context);
    _model = SearchModel(services.backend, services.messages);
    unawaited(_start());
  }

  /// Os recentes primeiro, para a letra já digitada achar arquivos também.
  Future<void> _start() async {
    await model.prepare();
    if (widget.initialText.isNotEmpty) await model.setQuery(widget.initialText);
  }

  @override
  void dispose() {
    _model?.dispose();
    _text.dispose();
    super.dispose();
  }

  void _open(SearchResult result) {
    final services = LauncherScope.of(context);
    final appId = result.appId;
    Navigator.of(context).pop();
    if (appId != null) {
      unawaited(services.controller.launchApp(appId));
    } else {
      unawaited(model.open(result));
    }
  }

  void _openFirst() {
    final results = model.value.results;
    if (results.isNotEmpty) _open(results.first);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return OverlayCard(
      title: 'Pesquisa',
      hint: const ButtonHints([
        ButtonHint(PadRole.confirm, 'abre'),
        ButtonHint(PadRole.back, 'fecha'),
      ]),
      width: Dimens.searchPanelWidth,
      height: size.height * _heightFactor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchInput(
            controller: _text,
            autofocus: true,
            hint: 'Aplicativos, arquivos, configurações...',
            onChanged: model.setQuery,
            onSubmit: _openFirst,
          ),
          const SizedBox(height: Dimens.gap),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: model,
              builder: (context, state, _) => _body(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(SearchState state) {
    final error = state.error;
    if (error != null) return MutedText('A pesquisa falhou: $error');
    if (state.isEmptyQuery) return const MutedText(searchEmptyText);
    if (state.results.isEmpty) {
      return MutedText(searchNothingFound(state.query.trim()));
    }
    return SearchResultsList(results: state.results, onOpen: _open);
  }
}
