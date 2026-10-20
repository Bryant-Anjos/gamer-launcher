import 'package:flutter/foundation.dart';
import 'package:gamer_launcher/backend/launcher_backend.dart';
import 'package:gamer_launcher/src/rust/api/search.dart';
import 'package:gamer_launcher/state/messages.dart';

/// Resultados mostrados na pesquisa global.
const searchResultsLimit = 30;

/// Estado de uma pesquisa: o texto, os resultados e o erro da última busca.
@immutable
class SearchState {
  const SearchState({this.query = '', this.results = const [], this.error});

  final String query;
  final List<SearchResult> results;
  final String? error;

  bool get isEmptyQuery => query.trim().isEmpty;
}

/// Pesquisa pelo núcleo (apps, recentes e páginas de configurações, com
/// siglas e sem acentos). Cada tecla dispara uma busca; a resposta de uma
/// busca antiga que chega depois de uma nova é descartada. [kinds] restringe
/// os tipos (o seletor de favoritos só quer apps).
class SearchModel extends ValueNotifier<SearchState> {
  SearchModel(
    this._backend,
    this._messages, {
    this.limit = searchResultsLimit,
    this.kinds,
  }) : super(const SearchState());

  final LauncherBackend _backend;
  final LauncherMessages _messages;
  final int limit;
  final Set<SearchKind>? kinds;
  int _generation = 0;
  bool _disposed = false;

  @override
  set value(SearchState next) {
    if (!_disposed) super.value = next;
  }

  /// Lê os recentes uma vez; sem eles a pesquisa segue com apps e páginas.
  Future<void> prepare() async {
    try {
      await _backend.prepareSearch();
    } on BackendException catch (error) {
      _messages.show(
        'A pesquisa não vai mostrar os recentes: ${error.message}',
      );
    }
  }

  Future<void> setQuery(String query) async {
    final generation = ++_generation;
    if (query.trim().isEmpty) {
      value = SearchState(query: query);
      return;
    }
    final next = await _search(query);
    if (generation == _generation) value = next;
  }

  Future<SearchState> _search(String query) async {
    try {
      final found = await _backend.search(query, limit);
      final wanted = kinds;
      return SearchState(
        query: query,
        results: wanted == null
            ? found
            : found.where((r) => wanted.contains(r.kind)).toList(),
      );
    } on BackendException catch (error) {
      return SearchState(query: query, error: error.message);
    }
  }

  /// Arquivos e páginas de configurações; apps abrem pelo controlador, que
  /// também lembra o último app aberto.
  Future<void> open(SearchResult result) async {
    try {
      await _backend.openSearchResult(result.id);
    } on BackendException catch (error) {
      _messages.show(
        'Não foi possível abrir ${result.title}: ${error.message}',
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
