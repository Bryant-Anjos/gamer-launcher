import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/search.dart';
import 'package:gamer_launcher/state/messages.dart';
import 'package:gamer_launcher/state/search_model.dart';

import '../support/fake_backend.dart';

class _Setup {
  _Setup({Set<SearchKind>? kinds}) {
    messages.stream.listen(shown.add);
    model = SearchModel(backend, messages, kinds: kinds);
  }

  final backend = FakeBackend();
  final messages = LauncherMessages();
  final shown = <String>[];
  late final SearchModel model;

  List<String> get titles => [for (final r in model.value.results) r.title];

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  test('an empty query shows nothing and asks nothing', () async {
    final s = _Setup();

    await s.model.setQuery('   ');

    expect(s.model.value.results, isEmpty);
    expect(s.model.value.isEmptyQuery, isTrue);
    expect(s.backend.calls.where((c) => c.startsWith('search')), isEmpty);
  });

  test('a query brings apps, files and settings', () async {
    final s = _Setup();

    await s.model.setQuery('a');

    expect(s.titles, containsAll(['Arquivos', 'granspace', 'Papel de parede']));
    expect(s.model.value.query, 'a');
  });

  test('the kind filter keeps only apps (favorites picker)', () async {
    final s = _Setup(kinds: {SearchKind.app});

    await s.model.setQuery('a');

    expect(
      s.model.value.results.every((r) => r.kind == SearchKind.app),
      isTrue,
    );
    expect(s.titles, contains('Arquivos'));
  });

  test('an answer to an older query is dropped', () async {
    final s = _Setup();
    final gate = Completer<void>();
    s.backend.gates['search'] = gate;

    final slow = s.model.setQuery('sp');
    await s.settle();
    s.backend.gates.remove('search');
    await s.model.setQuery('steam');
    gate.complete();
    await slow;

    expect(s.titles, ['Steam']);
    expect(s.model.value.query, 'steam');
  });

  test('a failed search shows the error instead of results', () async {
    final s = _Setup();
    s.backend.failures['search'] = 'catálogo indisponível';

    await s.model.setQuery('x');

    expect(s.model.value.error, 'catálogo indisponível');
    expect(s.model.value.results, isEmpty);
  });

  test('prepare reads the recents and a failure becomes a message', () async {
    final s = _Setup();
    s.backend.failures['prepareSearch'] = 'sem HOME';

    await s.model.prepare();
    await s.settle();

    expect(s.backend.calls, contains('prepareSearch'));
    expect(s.shown.single, contains('sem HOME'));
  });

  test('opening a result that fails says which one', () async {
    final s = _Setup();
    s.backend.failures['openSearchResult'] = 'arquivo não encontrado';
    const result = SearchResult(
      kind: SearchKind.file,
      id: 'file:/tmp/x',
      title: 'x',
    );

    await s.model.open(result);
    await s.settle();

    expect(s.backend.calls, contains('openSearchResult(file:/tmp/x)'));
    expect(s.shown.single, 'Não foi possível abrir x: arquivo não encontrado');
  });
}
