import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';
import '../support/samples.dart';

/// Pequena folga de arredondamento.
const _epsilon = 0.5;

/// Retângulo do anel de foco: o do item, crescido pela escala (centrada).
Rect _ringOf(WidgetTester tester, Finder tile) {
  final rect = tester.getRect(tile);
  final scale = tester
      .widget<AnimatedScale>(
        find.descendant(of: tile, matching: find.byType(AnimatedScale)).first,
      )
      .scale;
  return Rect.fromCenter(
    center: rect.center,
    width: rect.width * scale,
    height: rect.height * scale,
  );
}

Rect? _viewportOf(WidgetTester tester, Finder tile) {
  final scrollable = find.ancestor(of: tile, matching: find.byType(Scrollable));
  if (scrollable.evaluate().isEmpty) return null;
  return tester.getRect(scrollable.first);
}

bool _inside(Rect ring, Rect viewport) =>
    ring.left >= viewport.left - _epsilon &&
    ring.top >= viewport.top - _epsilon &&
    ring.right <= viewport.right + _epsilon &&
    ring.bottom <= viewport.bottom + _epsilon;

/// Foca cada item da página, um por vez, e confere que o anel de foco fica
/// inteiro dentro da área que rola (nada cortado em nenhuma borda).
Future<void> _expectNoClipping(WidgetTester tester) async {
  final content = find.byWidgetPredicate(
    (w) => w is Focus && w.focusNode?.debugLabel == 'content',
  );
  final tiles = find.descendant(of: content, matching: find.byType(FocusTile));
  final count = tiles.evaluate().length;
  expect(count, greaterThan(0));
  var checked = 0;
  for (var i = 0; i < count; i++) {
    final tile = tiles.at(i);
    if (tile.evaluate().isEmpty) continue;
    // um elemento dentro do item: o Focus.of dele é o nó do próprio item
    final node = Focus.maybeOf(
      tester.element(
        find.descendant(of: tile, matching: find.byType(AnimatedScale)).first,
      ),
    );
    if (node == null || !node.canRequestFocus) continue;
    node.requestFocus();
    await tester.pumpAndSettle();
    final viewport = _viewportOf(tester, tile);
    if (viewport == null) continue;
    final ring = _ringOf(tester, tile);
    expect(
      _inside(ring, viewport),
      isTrue,
      reason: 'item $i: anel $ring fora de $viewport',
    );
    checked++;
  }
  expect(checked, greaterThan(0), reason: 'nenhum item foi conferido');
}

Future<void> _openSection(WidgetTester tester, int tabs) async {
  final h = await pumpLauncher(
    tester,
    backend: FakeBackend(wallpapers: const ['/w/a.png', '/w/b.png']),
  );
  for (var i = 0; i < tabs; i++) {
    await h.pressAndSettle(tester, GamepadAction.tabNext);
  }
}

void main() {
  const sections = [
    'Início',
    'Aplicativos',
    'Jogos',
    'Arquivos',
    'Configurações',
  ];
  for (final (index, name) in sections.indexed) {
    testWidgets('no focused item is clipped in $name', (tester) async {
      await _openSection(tester, index);

      await _expectNoClipping(tester);
    });
  }

  testWidgets('no focused item is clipped in Claude', (tester) async {
    await pumpLauncher(
      tester,
      backend: FakeBackend(
        isClaudeInstalled: true,
        claudeNow: sampleClaudeNow,
        claudeStats: sampleClaudeStats,
      ),
    );
    await tester.tap(find.text('Claude'));
    await tester.pumpAndSettle();

    await _expectNoClipping(tester);
  });

  testWidgets('a very wide row grows only a few pixels when focused', (
    tester,
  ) async {
    await _openSection(tester, 3);
    final row = find
        .byType(FocusTile)
        .evaluate()
        .where((e) => tester.getRect(find.byWidget(e.widget)).width > 600);
    expect(row, isNotEmpty);
    final tile = find.byWidget(row.first.widget);
    Focus.of(
      tester.element(
        find.descendant(of: tile, matching: find.byType(Focus)).first,
      ),
    ).requestFocus();
    await tester.pumpAndSettle();

    final grown = _ringOf(tester, tile).width - tester.getRect(tile).width;
    expect(grown, lessThanOrEqualTo(16 + _epsilon));
  });
}
